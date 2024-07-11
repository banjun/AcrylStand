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
    var image: UIImage
    @State private var path: Result<UIBezierPath, Error>?
    @State private var ciImage: CIImage?

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
                realityView(path).id(reloader.dateReloaded)
            case .failure(let error):
                Text(String(describing: error))
            }
        }
        .onAppear {
            let blend = CIFilter.blendWithAlphaMask()
            blend.backgroundImage = CIImage(color: .black).cropped(to: .init(origin: .zero, size: image.size))
            blend.inputImage = CIImage(color: .white).cropped(to: .init(origin: .zero, size: image.size))
            blend.maskImage = CIImage(image: image)
            let blend2 = CIFilter.sourceOverCompositing()
            let legSize = CGSize(width: image.size.width * 0.2, height: image.size.height * 0.2)
            let morphMax = CIFilter.morphologyMaximum()
            morphMax.radius = 50
            let morphMin = CIFilter.morphologyMinimum()
            morphMin.radius = 10
            let morphMax2 = CIFilter.morphologyMaximum()
            morphMax2.radius = 10
            let morphMin2 = CIFilter.morphologyMinimum()
            morphMin2.radius = 1 // > 0 value helps edge process

            blend2.backgroundImage = blend.outputImage
            blend2.inputImage = CIImage(color: .white).cropped(to: .init(x: (image.size.width - legSize.width) / 2, y: 0, width: legSize.width, height: legSize.height))
            morphMax.inputImage = blend2.outputImage
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

    private func realityView(_ path: UIBezierPath) -> some View {
        RealityView { content in
            let scene = try! await Entity(named: "AcrylStand")
            let acrylEntity = scene.findEntity(named: "Image")! as! ModelEntity

            let points = (0..<256)
                .map { CGFloat($0) / 255 }
                .map { path.mx_point(atFractionOfLength: $0) } // x,y in 0...1
                .reversed()
            let vertices: [SIMD3<Float>] = points
                .map { SIMD3<Float>(Float($0.x) - 0.5, 1 - Float($0.y) - 0.5, -7) } // x,y in -0.5...+0.5 (centered)
            let scale: Float = 0.1
            var meshDescriptor = MeshDescriptor()
            meshDescriptor.positions = .init(
                vertices.map { $0 * scale }
                +
                vertices.reversed().map { .init($0.x, $0.y, -8) * scale })
            meshDescriptor.primitives = .polygons(
                [255, 255],
                Array(0..<512))
            meshDescriptor.textureCoordinates = .init(
                points.map { SIMD2<Float>(
                    min(1, max(0, Float($0.x))),
                    1 - min(1, max(0, Float($0.y))))
                }
                +
                points.reversed().map { SIMD2<Float>(
                    min(1, max(0, Float($0.x))),
                    1 - min(1, max(0, Float($0.y))))
                })

            var sideMeshDescriptor = MeshDescriptor()
            sideMeshDescriptor.positions = meshDescriptor.positions
            let sideQuads: [UInt32] = (UInt32(0)..<UInt32(255)).flatMap { i in
                [UInt32(511) - i, UInt32(511) - (i + 1),
                 i + 1, i]
            }
            sideMeshDescriptor.primitives = .trianglesAndQuads(triangles: [], quads: sideQuads)


            let sortGroup = ModelSortGroup(depthPass: nil)
            acrylEntity.model!.mesh = try! await .init(from: [meshDescriptor])
            //                    acrylEntity.model!.materials = [UnlitMaterial(color: .green)]
            acrylEntity.components.set(ModelSortGroupComponent(group: sortGroup, order: 3))
            content.add(acrylEntity)

            var acrylPBM = PhysicallyBasedMaterial()
            acrylPBM.blending = .transparent(opacity: 0.0)
            acrylPBM.baseColor = .init(tint: .clear)
            acrylPBM.metallic = 0.0
            acrylPBM.roughness = 0.05
            acrylPBM.specular = 1.4

            let outer = acrylEntity.clone(recursive: true)
            outer.model!.mesh = try! await .init(from: [sideMeshDescriptor])
            outer.components.set(ModelSortGroupComponent(group: sortGroup, order: 1))
            //                     outer.model!.materials = [UnlitMaterial(color: .green)]
            outer.model!.materials = [acrylPBM]
            content.add(outer)

            // inverted for double sided materials
            let sideQuadsInverted: [UInt32] = (UInt32(0)..<UInt32(255)).flatMap { i in
                [i, i + 1,
                 UInt32(511) - (i + 1), UInt32(511) - i]
            }
            sideMeshDescriptor.primitives = .trianglesAndQuads(triangles: [], quads: sideQuadsInverted)
            let inner = acrylEntity.clone(recursive: true)
            inner.model!.mesh = try! await .init(from: [sideMeshDescriptor])
            inner.components.set(ModelSortGroupComponent(group: sortGroup, order: 2))
            inner.model!.materials = [acrylPBM]
            content.add(inner)
        }
    }
}
