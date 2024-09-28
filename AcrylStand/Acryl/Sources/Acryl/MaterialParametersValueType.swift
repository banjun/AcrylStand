import RealityFoundation
import CoreGraphics

extension ShaderGraphMaterial {
    internal mutating func setByArgName(caller: String = #function, _ value: MaterialParametersValueType) throws {
        let name = (try? /\((\w+):/.firstMatch(in: caller).map {String($0.output.1)}) ?? caller
        let value: MaterialParameters.Value = switch value {
        case let v as TextureResource: .textureResource(v)
        case let v as Float: .float(v)
        case let v as SIMD2<Float>: .simd2Float(v)
        case let v as SIMD3<Float>: .simd3Float(v)
        case let v as SIMD4<Float>: .simd4Float(v)
        case let v as CGColor: .color(v)
        case let v as float2x2: .float2x2(v)
        case let v as float3x3: .float3x3(v)
        case let v as float4x4: .float4x4(v)
        case let v as Bool: .bool(v)
        case let v as Int32: .int(v)
        default: fatalError("unimplemented type: \(type(of: value)), value = \(String(describing: value))")
        }
        return try self.setParameter(name: name, value: value)
    }
}
protocol MaterialParametersValueType {}
extension TextureResource: MaterialParametersValueType {}
extension Float: MaterialParametersValueType {}
extension SIMD2<Float>: MaterialParametersValueType {}
extension SIMD3<Float>: MaterialParametersValueType {}
extension SIMD4<Float>: MaterialParametersValueType {}
extension CGColor: MaterialParametersValueType {}
extension float2x2: MaterialParametersValueType {}
extension float3x3: MaterialParametersValueType {}
extension float4x4: MaterialParametersValueType {}
extension Bool: MaterialParametersValueType {}
extension Int32: MaterialParametersValueType {}
