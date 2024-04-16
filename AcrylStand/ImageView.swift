import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageView: View {
    var image: UIImage
    @State private var path: Result<UIBezierPath, Error>?
    @State private var ciImage: CIImage?

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()

            switch path {
            case nil:
                EmptyView()
            case .success(let path):
                GeometryReader { g in
                    Path({
                        let path = path.copy() as! UIBezierPath
                        path.apply(.init(scaleX: g.size.width, y: g.size.height))
                        return path.cgPath
                    }())
                    .stroke(.green, lineWidth: 20)
                    .fill(.white.opacity(0.2))
                }
            case .failure(let error):
                Text(String(describing: error))
            }
        }
        .onAppear {
            let blend = CIFilter.blendWithAlphaMask()
            blend.backgroundImage = CIImage(color: .black).cropped(to: .init(origin: .zero, size: image.size))
            blend.inputImage = CIImage(color: .white).cropped(to: .init(origin: .zero, size: image.size))
            blend.maskImage = CIImage(image: image)
            let morphMax = CIFilter.morphologyMaximum()
            morphMax.radius = 50
            let morphMin = CIFilter.morphologyMinimum()
            morphMin.radius = 10
            let morphMax2 = CIFilter.morphologyMaximum()
            morphMax2.radius = 10
            let morphMin2 = CIFilter.morphologyMinimum()
            morphMin2.radius = 1 // > 0 value helps edge process

            morphMax.inputImage = blend.outputImage
            morphMin.inputImage = morphMax.outputImage?.cropped(to: .init(origin: .zero, size: image.size))
            morphMax2.inputImage = morphMin.outputImage?.cropped(to: .init(origin: .zero, size: image.size))
            morphMin2.inputImage = morphMax2.outputImage?.cropped(to: .init(origin: .zero, size: image.size))
            guard let image = morphMin2.outputImage?.cropped(to: .init(origin: .zero, size: image.size)) else { return }
//            let uiImage = UIImage(ciImage: image)
//            NSLog("%@", "output = \(uiImage)")

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
}
