import Foundation
import SwiftUI
import UIKit
import RealityKit
import CryptoKit
@testable import AcrylStand

extension ImageView {
    @_dynamicReplacement(for: realityView(_:))
    func realityView2(_ path: UIBezierPath) -> some View {
        RealityView { content in
            guard let imageData = imageModel.selectedImage else { return }
            let scene = try! await Entity(named: "AcrylStand")
            let acrylEntity = scene.findEntity(named: "Image")! as! ModelEntity

            let randomImageName = SHA256.hash(data: imageData).map {String(format: "%02x", $0)}.joined()
            let tmpImageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(randomImageName).appendingPathExtension("png")
            try! imageData.write(to: tmpImageURL)
            await setIdolImage(of: acrylEntity, image: try! TextureResource(contentsOf: tmpImageURL))

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
            let image = UIImage(data: imageData)!
            let textureWidthScale: Float = Float(image.size.width / max(image.size.width, image.size.height))
            let textureHeightScale: Float = Float(image.size.height / max(image.size.width, image.size.height))
            meshDescriptor.textureCoordinates = .init(
                points.map { SIMD2<Float>(
                    min(1, max(0, 0.5 + (Float($0.x) - 0.5) / textureWidthScale)),
                    1 - min(1, max(0, 0.5 + (Float($0.y) - 0.5) / textureHeightScale)))
                }
                +
                points.reversed().map { SIMD2<Float>(
                    min(1, max(0, 0.5 + (Float($0.x) - 0.5) / textureWidthScale)),
                    1 - min(1, max(0, 0.5 + (Float($0.y) - 0.5) / textureHeightScale)))
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
            acrylPBM.metallic = 1.0
            acrylPBM.roughness = 0.0
            acrylPBM.specular = 1.5

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
        .scaleEffect(3)
        .frame(width: 1000, height: 1000)
    }
}
