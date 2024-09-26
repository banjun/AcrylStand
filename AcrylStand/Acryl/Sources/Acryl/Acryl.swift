import Foundation

/// Bundle for the Acryl project
public let acrylBundle = Bundle.module


import RealityFoundation

public final actor AcrylShader {
    public private(set) var shaderGraph: ShaderGraphMaterial

    public init() async throws {
        shaderGraph = try await ShaderGraphMaterial(named: "/AcrylStandShader", from: "Scene", in: acrylBundle)
    }
    public init(image: TextureResource, size: SIMD3<Float>) async throws {
        try await self.init()
        try set(image: image)
        try set(unscaledExtent: size)
    }

    public func set(image: TextureResource) throws {
        try shaderGraph.setParameter(name: "image", value: .textureResource(image))
    }
    public func set(unscaledExtent size: SIMD3<Float>) throws {
        try shaderGraph.setParameter(name: "unscaledExtent", value: .simd3Float(size))
    }
}

extension ModelEntity {
    public convenience init(acrylMesh mesh: MeshResource, acrylShader: AcrylShader) async {
        self.init(mesh: mesh, shaderGraph: await acrylShader.shaderGraph)
    }
    public convenience init(mesh: MeshResource, shaderGraph: ShaderGraphMaterial) {
        self.init(mesh: mesh, materials: [shaderGraph])
    }
}
