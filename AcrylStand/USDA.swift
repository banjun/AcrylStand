import RealityFoundation
import Foundation

struct USDA {
    var name: String
    var points: [SIMD3<Float>]
    var faceVertexIndices: [UInt32]
    var faceVertexCounts: [UInt32]
    var texCoords: [SIMD2<Float>]
    var texCoordsIndices: [UInt32]
    init(name: String, meshDescriptor: MeshDescriptor) {
        self.name = name
        self.points = .init(meshDescriptor.positions)
        switch meshDescriptor.primitives {
        case .polygons(let vertexCounts, let vertexIndices):
            self.faceVertexCounts = vertexCounts.map(UInt32.init)
            self.faceVertexIndices = vertexIndices
        case .triangles(let vertexIndices):
            self.faceVertexCounts = .init(repeating: 3, count: vertexIndices.count / 3)
            self.faceVertexIndices = vertexIndices
        case .trianglesAndQuads(let triangles, let quads):
            self.faceVertexCounts = [UInt32](repeating: 3, count: triangles.count / 3) + [UInt32](repeating: 4, count: quads.count / 4)
            self.faceVertexIndices = triangles + quads
        case nil:
            self.faceVertexCounts = []
            self.faceVertexIndices = []
        @unknown default: fatalError("TODO")
        }
        self.texCoords = meshDescriptor.textureCoordinates?.elements ?? []
        self.texCoordsIndices = self.texCoords.enumerated().map(\.offset).map(UInt32.init)
    }

    func write(to file: URL) throws {
        let preamble = """
#usda 1.0
(
    defaultPrim = "Root"
    metersPerUnit = 1
    upAxis = "Y"
)
"""
        let texCoordsText = texCoords.isEmpty ? "" : """
    texCoord2f[] primvars:st = \(texCoords.map {($0.x, $0.y)}) (
        interpolation = "vertex"
    )
    int[] primvars:st:indices = \(texCoordsIndices)        
"""
        let meshText = """
def Mesh \"\(name)\" {
    float3[] points = \(points.map {($0.x, $0.y, $0.z)})
    int[] faceVertexIndices = \(faceVertexIndices)
    int[] faceVertexCounts = \(faceVertexCounts)
\(texCoordsText)
}
"""
        let serialized = [preamble, meshText].joined(separator: "\n")
        try serialized.data(using: .utf8)!
            .write(to: file)
    }
}
