import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import RealityKit
import RealityFoundation

struct ImageView: View {
#if DEBUG
    @ObservedObject private var reloader = AcrylStandApp.reloader
#endif
    @Environment(ImageModel.self) private var imageModel
    @State private var path: Result<UIBezierPath, Error>?
    @State private var rotation: Rotation3D = .identity
    @State private var rootEntity: Entity?
    @GestureState private var rotationOnDragStart: Rotation3D?

    var body: some View {
        ZStack {
//            Image(uiImage: image)
//                .resizable()

            switch path {
            case nil:
                EmptyView()
            case .success(let path):
//                GeometryReader { g in
//                    Path({
//                        let path = path.copy() as! UIBezierPath
//                        path.apply(.init(scaleX: g.size.width, y: g.size.height))
//                        return path.cgPath
//                    }())
////                    .stroke(.green, lineWidth: 20)
//                    .fill(.white.opacity(0.2))
//                }
                realityView(path)
#if DEBUG
                    .id(reloader.dateReloaded)
#endif
                if rootEntity == nil { ProgressView() }
            case .failure(let error):
                Text(String(describing: error))
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            if imageModel.leggedImage == nil {
                imageModel.generateMaskImage()
            }
            guard let image = imageModel.leggedImage else { return }

            let request = VNDetectContoursRequest { req, error in
                guard let observation = req.results?.first as? VNContoursObservation else { return }
                if let error {
                    NSLog("%@", "\(String(describing: error))")
                    path = .failure(error)
                    return
                }

                guard let maxContour = (observation.topLevelContours.max { $0.pointCount < $1.pointCount }) else { return }
                let contour = (maxContour.childContours.max { $0.pointCount < $1.pointCount }) ?? maxContour
                let path = UIBezierPath(cgPath: contour.normalizedPath)
                path.apply(CGAffineTransform.identity
                           //                    .scaledBy(x: image.extent.width, y: -image.extent.height)
                    .scaledBy(x: 1, y: -1)
                    .translatedBy(x: 0, y: -1))
                self.path = .success(path)
            }
            request.maximumImageDimension = Int(max(image.extent.width, image.extent.height))
//            request.contrastAdjustment =
//            request.contrastPivot =
//            request.detectsDarkOnLight = true
            let handler = VNImageRequestHandler(ciImage: image)
            do {
                try handler.perform([request])
            } catch {
                NSLog("%@", "\(String(describing: error))")
                path = .failure(error)
            }
        }
    }

    private func realityView(_ path: UIBezierPath) -> some View {
        RealityView { content in
            guard let imageData = imageModel.selectedImage else { return }
            let acrylEntity = try! await AcrylEntity(imageData: imageData, path: path)
            self.rootEntity = acrylEntity

            content.add(acrylEntity)
        } update: { content in
            guard let root = rootEntity else { return }
            root.transform.rotation = .init(rotation)
        }.gesture(DragGesture().targetedToEntity(rootEntity ?? Entity())
            .updating($rotationOnDragStart) { value, state, transaction in
                state = rotationOnDragStart ?? rotation
            }.onChanged { value in
                guard let rotationOnDragStart else { return }
                rotation = rotationOnDragStart.rotated(by: Rotation3D(angle: .degrees(value.translation3D.x), axis: .y))
            })
        .scaleEffect(3)
        .frame(width: 1000, height: 1000)
    }
}

