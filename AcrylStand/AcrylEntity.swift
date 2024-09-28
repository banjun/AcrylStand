import RealityKit
import Foundation
import UIKit
import CryptoKit
import Acryl
import SwiftUI

final class AcrylEntity: Entity {
    @available(*, unavailable) required init() { fatalError() }

    static func meshDescriptor(textureSize: CGSize, path: UIBezierPath, pathPoints: UInt8, depth: Float) -> MeshDescriptor {
        let points = (0..<pathPoints)
            .map { CGFloat($0) / CGFloat(pathPoints) }
            .map { path.mx_point(atFractionOfLength: $0) } // x,y in 0...1
            .reversed()
//        print(points)
        let vertices: [SIMD3<Float>] = points
            .map { SIMD3<Float>(Float($0.x) - Float(0.5), Float(1) - Float($0.y) - Float(0.5), depth / 2) } // x,y in -0.5...+0.5 (centered)
        let scale: Float = 0.1
        var meshDescriptor = MeshDescriptor()
        meshDescriptor.positions = MeshBuffers.Positions(
            vertices.map { $0 * scale }
            +
            vertices.reversed().map { SIMD3<Float>($0.x, $0.y, -depth / 2) * scale })
        meshDescriptor.primitives = .polygons(
            [pathPoints, pathPoints],
            Array(0..<UInt32(pathPoints)) + Array(UInt32(pathPoints)..<(UInt32(pathPoints) * 2)))
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
        // NSLog("%@", "textureWidthScale = \(textureWidthScale), textureHeightScale = \(textureHeightScale)")
        let pathPoints = 255
        let depth: Float = 0.03
        let meshDescriptor = Self.meshDescriptor(textureSize: textureSize, path: path, pathPoints: UInt8(pathPoints), depth: depth)

        // - MARK
        // try USDA(name: "side", meshDescriptor: sideMeshDescriptor).write(to: URL(fileURLWithPath: "/Users/banjun/Downloads/usda-export-side.usda"))
        // - MARK

        let scale: Float = 0.1
        let sortGroup = ModelSortGroup(depthPass: nil)
        let acrylShader = try await AcrylShader(
            image: TextureResource(contentsOf: tmpImageURL),
            size: SIMD3<Float>(x: textureWidthScale, y: textureHeightScale, z: 1) * scale)

        let acrylEntity: ModelEntity
        if #available(visionOS 2.0, *) {
            // var count = 0
            // path.cgPath.applyWithBlock {_ in count += 1}
            // NSLog("%@", "path count = \(count)") // -> typically 4000 poitns
            // -
            // reduce path points for smooth surface
            let reducedPoints = (0..<pathPoints)
                .map { CGFloat($0) / CGFloat(pathPoints) }
                .map { path.mx_point(atFractionOfLength: $0) } // x,y in 0...1
                .reversed()
            let reducedPaths = reducedPoints.reduce(into: Path()) { $0.isEmpty ? $0.move(to: $1) : $0.addLine(to: $1) }
                .applying(.init(scaleX: CGFloat(scale), y: CGFloat(scale)).translatedBy(x: -0.5, y: -0.5).scaledBy(x: 1, y: -1).translatedBy(x: 0, y: -1))
            var extrusionOptions = MeshResource.ShapeExtrusionOptions()
            extrusionOptions.extrusionMethod = .linear(depth: depth * scale)
            // extrusionOptions.boundaryResolution = .uniformSegmentsPerSpan(segmentCount: 64)
            // extrusionOptions.chamferResolution = .uniformSegmentsPerSpan(segmentCount: 1)
            // extrusionOptions.materialAssignment = .init(assignAll: 0)
            let mesh = try await MeshResource(extruding: reducedPaths, extrusionOptions: extrusionOptions)
            acrylEntity = await ModelEntity(acrylMesh: mesh, acrylShader: acrylShader)
        } else {
            acrylEntity = try await ModelEntity(acrylMesh: .generate(from: [meshDescriptor]), acrylShader: acrylShader)
        }
        acrylEntity.components.set(ModelSortGroupComponent(group: sortGroup, order: 3))
        acrylEntity.components.set(InputTargetComponent())
        acrylEntity.components.set(GroundingShadowComponent(castsShadow: true))
        if #available(visionOS 2, *) {
            let collision = try! await ShapeResource.generateStaticMesh(from: .generate(from: [meshDescriptor]))
            acrylEntity.components.set(CollisionComponent(shapes: [collision]))
        }
//         acrylEntity.model!.materials = [{var m = UnlitMaterial(color: .cyan); m.triangleFillMode = .lines; return m}()]
//         acrylEntity.components.set(ModelDebugOptionsComponent(visualizationMode: .textureCoordinates))
        addChild(acrylEntity)

        // - MARK
//         try USDA(name: "main", meshDescriptor: meshDescriptor).write(to: URL(fileURLWithPath: "/Users/banjun/Downloads/usda-export.usda"))
        // - MARK

        var acrylPBM = PhysicallyBasedMaterial()
        acrylPBM.blending = .transparent(opacity: 0.0)
        acrylPBM.baseColor = .init(tint: .clear)
        acrylPBM.metallic = 0.0
        acrylPBM.roughness = 0.05
        acrylPBM.specular = 1.49

        var sideMeshDescriptor = MeshDescriptor()
        sideMeshDescriptor.positions = meshDescriptor.positions
        sideMeshDescriptor.textureCoordinates = .init(zip(meshDescriptor.textureCoordinates?.elements ?? [], meshDescriptor.positions).map {
            SIMD2<Float>(1 - max(0, min(1, ($1.z + 0.05) * 10)),
                         $0.y)
        })
        let sideQuads: [UInt32] = (UInt32(0)..<UInt32(pathPoints)).flatMap { i in
            [UInt32(pathPoints * 2 - 1) - i, UInt32(pathPoints * 2 - 1) - (i + UInt32(1)),
             i + UInt32(1), i]
        }
        sideMeshDescriptor.primitives = .trianglesAndQuads(triangles: [], quads: sideQuads)

        // inverted for double sided materials
        let sideQuadsInverted: [UInt32] = (UInt32(0)..<UInt32(pathPoints)).flatMap { i in
            [i, i + UInt32(1),
             UInt32(pathPoints * 2 - 1) - (i + UInt32(1)), UInt32(pathPoints * 2 - 1) - i]
        }
        var sideMeshInvertedDescriptor = sideMeshDescriptor
        sideMeshInvertedDescriptor.primitives = .trianglesAndQuads(triangles: [], quads: sideQuadsInverted)
        let inner = acrylEntity.clone(recursive: true)
        inner.model!.mesh = try .generate(from: [sideMeshInvertedDescriptor])
        inner.components.set(ModelSortGroupComponent(group: sortGroup, order: 2))
        inner.model!.materials = [acrylPBM]
        addChild(inner)

        // TODO: move sideMeshInvertedDescriptor -> acrylEntity
    }
}


