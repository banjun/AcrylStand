import RealityKit
import Foundation
import UIKit
import CryptoKit
import Acryl

final class AcrylEntity: Entity {
    @available(*, unavailable) required init() { fatalError() }

    static let prototypeEntity: ModelEntity = {
        let scene = try! Entity.load(named: "Scene", in: acrylBundle)
        let acrylEntity = scene.findEntity(named: "Main")! as! ModelEntity
        return acrylEntity
    }()

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
        let acrylEntity = Self.prototypeEntity.clone(recursive: true)

        let randomImageName = SHA256.hash(data: imageData).map {String(format: "%02x", $0)}.joined()
        let tmpImageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(randomImageName).appendingPathExtension("png")
        try imageData.write(to: tmpImageURL)
        setIdolImage(of: acrylEntity, image: try! await TextureResource(contentsOf: tmpImageURL))

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
//        acrylEntity.model!.mesh = try await MeshResource(from: [meshDescriptor])
        //                    acrylEntity.model!.materials = [UnlitMaterial(color: .green)]
        acrylEntity.components.set(ModelSortGroupComponent(group: sortGroup, order: 3))
//        acrylEntity.components.set(ModelDebugOptionsComponent(visualizationMode: .textureCoordinates))
        acrylEntity.components.set(InputTargetComponent())
        acrylEntity.components.set(GroundingShadowComponent(castsShadow: true))
        addChild(acrylEntity)

        var acrylPBM = PhysicallyBasedMaterial()
        acrylPBM.blending = .transparent(opacity: 0.0)
        acrylPBM.baseColor = .init(tint: .clear)
        acrylPBM.metallic = 0.0
        acrylPBM.roughness = 0.05
        acrylPBM.specular = 1.4

        let outer = acrylEntity.clone(recursive: true)
        outer.model!.mesh = try await MeshResource(from: [sideMeshDescriptor])
        outer.components.set(ModelSortGroupComponent(group: sortGroup, order: 1))
        //                     outer.model!.materials = [UnlitMaterial(color: .green)]
        outer.model!.materials = [acrylPBM]
//        addChild(outer)

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

        acrylEntity.model!.mesh = try await MeshResource(from: [meshDescriptor, sideMeshDescriptor, sideMeshInvertedDescriptor])
        if #available(visionOS 2, *) {
            let collision = try! await ShapeResource.generateStaticMesh(from: MeshResource(from: [meshDescriptor, sideMeshDescriptor]))
            acrylEntity.components.set(CollisionComponent(shapes: [collision]))
        }
        setUnscaledExtent(of: acrylEntity, size: .init(x: textureWidthScale, y: textureHeightScale, z: 1) * 0.1)
    }

    func setIdolImage(of idolImageEntity: ModelEntity, image: TextureResource) {
        setShaderGraphMaterial(of: idolImageEntity, name: "image", value: .textureResource(image))
    }

    func setUnscaledExtent(of idolImageEntity: ModelEntity, size: SIMD3<Float>) {
        setShaderGraphMaterial(of: idolImageEntity, name: "unscaledExtent", value: .simd3Float(size))
    }

    // custom shaders must be set in RCP file
    func setShaderGraphMaterial(of modelEntity: ModelEntity, name: String, value: MaterialParameters.Value) {
        var material = modelEntity.model!.materials[0] as! ShaderGraphMaterial
        try! material.setParameter(name: name, value: value)
        modelEntity.model!.materials[0] = material
    }
}


