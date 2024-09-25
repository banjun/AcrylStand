import Foundation

/// Bundle for the Acryl project
public let acrylBundle = Bundle.module


import RealityFoundation

public final actor AcrylShader {
    public private(set) var shaderGraph: ShaderGraphMaterial
    public init() async throws {
        shaderGraph = try await ShaderGraphMaterial(named: "/AcrylStandShader", from: "Scene", in: acrylBundle)
    }
    public func set(image: TextureResource) throws {
        try shaderGraph.setParameter(name: "image", value: .textureResource(image))
    }
    public func setUnscaledExtent(size: SIMD3<Float>) throws {
        try shaderGraph.setParameter(name: "unscaledExtent", value: .simd3Float(size))
    }
}

extension ModelEntity {
    public static func acrylEntity(mesh: MeshResource, acrylShader: AcrylShader) async -> ModelEntity {
        ModelEntity(mesh: mesh, materials: [await acrylShader.shaderGraph])
    }
}
