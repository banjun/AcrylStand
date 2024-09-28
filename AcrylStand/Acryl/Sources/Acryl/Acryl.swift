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
        self.image = image
        self.unscaledExtent = size
    }

    public var image: TextureResource { get {shaderGraph.getByVarName()} set {try! shaderGraph.setByVarName(newValue)} }
    public var unscaledExtent: SIMD3<Float> { get {shaderGraph.getByVarName()} set {try! shaderGraph.setByVarName(newValue)} }
}

extension ModelEntity {
    public convenience init(acrylMesh mesh: MeshResource, acrylShader: AcrylShader) async {
        self.init(mesh: mesh, shaderGraph: await acrylShader.shaderGraph)
    }
    public convenience init(mesh: MeshResource, shaderGraph: ShaderGraphMaterial) {
        self.init(mesh: mesh, materials: [shaderGraph])
    }
}
