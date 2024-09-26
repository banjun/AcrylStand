import RealityKit
import Foundation
import UIKit
import CryptoKit
import Acryl

final class AcrylEntity: Entity {
    @available(*, unavailable) required init() { fatalError() }

    static func meshDescriptor(textureSize: CGSize, path: UIBezierPath) -> MeshDescriptor {
        let points = (0..<256)
            .map { CGFloat($0) / CGFloat(255) }
            .map { path.mx_point(atFractionOfLength: $0) } // x,y in 0...1
            .reversed()
        let vertices: [SIMD3<Float>] = points
            .map { SIMD3<Float>(Float($0.x) - Float(0.5), Float(1) - Float($0.y) - Float(0.5), Float(0)) } // x,y in -0.5...+0.5 (centered)
        let scale: Float = 0.1
        var meshDescriptor = MeshDescriptor()
        meshDescriptor.positions = MeshBuffers.Positions(
            vertices.map { $0 * scale }
            +
            vertices.reversed().map { SIMD3<Float>($0.x, $0.y, -Float(0.025 * 2)) * scale })
        meshDescriptor.primitives = .polygons(
            [255, 255],
            Array(0..<255) + Array(256..<511))
        let textureWidthScale: Float = Float(textureSize.width / max(textureSize.width, textureSize.height))
        let textureHeightScale: Float = Float(textureSize.height / max(textureSize.width, textureSize.height))
        meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
            points.map { SIMD2<Float>(
                min(Float(1), max(Float(0), Float(0.5) + (Float($0.x) - Float(0.5)) / textureWidthScale)),
                Float(1) - min(Float(1), max(Float(0), Float(0.5) + (Float($0.y) - Float(0.5)) / textureHeightScale)))
            }
            +
            points.reversed().map { SIMD2<Float>(
                min(Float(1), max(Float(0), Float(0.5) + (Float($0.x) - Float(0.5)) / textureWidthScale)),
                Float(1) - min(Float(1), max(Float(0), Float(0.5) + (Float($0.y) - Float(0.5)) / textureHeightScale)))
            })
        return meshDescriptor
    }

    init(imageData: Data, path: UIBezierPath) async throws {
        super.init()

        let randomImageName = SHA256.hash(data: imageData).map {String(format: "%02x", $0)}.joined()
        let tmpImageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(randomImageName).appendingPathExtension("png")
        try imageData.write(to: tmpImageURL)

        let textureSize = UIImage(data: imageData)!.size
        let textureWidthScale: Float = Float(textureSize.width / max(textureSize.width, textureSize.height))
        let textureHeightScale: Float = Float(textureSize.height / max(textureSize.width, textureSize.height))
        NSLog("%@", "textureWidthScale = \(textureWidthScale), textureHeightScale = \(textureHeightScale)")
        let meshDescriptor = Self.meshDescriptor(textureSize: textureSize, path: path)

        // - MARK
        // try USDA(name: "main", meshDescriptor: meshDescriptor).write(to: URL(fileURLWithPath: "/Users/banjun/Downloads/usda-export.usda"))
        // - MARK

        var sideMeshDescriptor = MeshDescriptor()
        sideMeshDescriptor.positions = meshDescriptor.positions
        sideMeshDescriptor.textureCoordinates = .init(zip(meshDescriptor.textureCoordinates?.elements ?? [], meshDescriptor.positions).map {
            SIMD2<Float>(1 - max(0, min(1, ($1.z + 0.05) * 10)),
                         $0.y)
        })
        let sideQuads: [UInt32] = (UInt32(0)..<UInt32(255)).flatMap { i in
            [UInt32(511) - i, UInt32(511) - (i + UInt32(1)),
             i + UInt32(1), i]
        }
        sideMeshDescriptor.primitives = .trianglesAndQuads(triangles: [], quads: sideQuads)
        // - MARK
        // try USDA(name: "side", meshDescriptor: sideMeshDescriptor).write(to: URL(fileURLWithPath: "/Users/banjun/Downloads/usda-export-side.usda"))
        // - MARK

        let sortGroup = ModelSortGroup(depthPass: nil)
        let acrylShader = try await AcrylShader(
            image: TextureResource(contentsOf: tmpImageURL),
            size: SIMD3<Float>(x: textureWidthScale, y: textureHeightScale, z: 1) * Float(0.1))
        let acrylEntity = try await ModelEntity(acrylMesh: .init(from: [meshDescriptor, sideMeshDescriptor]), acrylShader: acrylShader)
        acrylEntity.components.set(ModelSortGroupComponent(group: sortGroup, order: 3))
        //        acrylEntity.components.set(ModelDebugOptionsComponent(visualizationMode: .textureCoordinates))
        acrylEntity.components.set(InputTargetComponent())
        acrylEntity.components.set(GroundingShadowComponent(castsShadow: true))
        if #available(visionOS 2, *) {
            let collision = try! await ShapeResource.generateStaticMesh(from: MeshResource(from: [meshDescriptor, sideMeshDescriptor]))
            acrylEntity.components.set(CollisionComponent(shapes: [collision]))
        }
        addChild(acrylEntity)

        var acrylPBM = PhysicallyBasedMaterial()
        acrylPBM.blending = .transparent(opacity: 0.0)
        acrylPBM.baseColor = .init(tint: .clear)
        acrylPBM.metallic = 0.0
        acrylPBM.roughness = 0.05
        acrylPBM.specular = 1.4

        // inverted for double sided materials
        let sideQuadsInverted: [UInt32] = (UInt32(0)..<UInt32(255)).flatMap { i in
            [i, i + UInt32(1),
             UInt32(511) - (i + UInt32(1)), UInt32(511) - i]
        }
        var sideMeshInvertedDescriptor = sideMeshDescriptor
        sideMeshInvertedDescriptor.primitives = .trianglesAndQuads(triangles: [], quads: sideQuadsInverted)
        let inner = acrylEntity.clone(recursive: true)
        inner.model!.mesh = try await MeshResource(from: [sideMeshInvertedDescriptor])
        inner.components.set(ModelSortGroupComponent(group: sortGroup, order: 2))
        inner.model!.materials = [acrylPBM]
        addChild(inner)

        // TODO: move sideMeshInvertedDescriptor -> acrylEntity
    }
}


