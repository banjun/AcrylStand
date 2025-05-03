import SwiftUI
import RealityKit

final class MirrorSpace {
    let root: Entity
    let mirror: Entity
    let entity: Entity
    let sortGroup = ModelSortGroup(depthPass: .postPass)

    @MainActor init(original: Entity, image: UIImage, path: UIBezierPath, mirrorSize: SIMD2<Float> = .init(0.15, 0.2)) async {
        let mirroredImage = ImageRenderer(
            content: Image(uiImage: image).scaleEffect(x: -1)
        ).uiImage!.pngData()!
        let mirroredPath = path
        mirroredPath.apply(.identity.translatedBy(x: 1, y: 0).scaledBy(x: -1, y: 1))
        entity = try! await AcrylEntity(imageData: mirroredImage, path: mirroredPath)
        entity.components.set(MirrorReceiverComponent(original: original))

        var mirrorMaterial = PhysicallyBasedMaterial()
        mirrorMaterial.baseColor = .init(tint: .white)
        mirrorMaterial.blending = .opaque // .transparent(opacity: 0.95)
        mirrorMaterial.metallic = 1.0
        mirrorMaterial.roughness = 0.0
        mirrorMaterial.specular = 1.0
        mirror = ModelEntity(mesh: .generatePlane(width: mirrorSize.x, height: mirrorSize.y), materials: [mirrorMaterial])
        mirror.components.set(EnvironmentLightingConfigurationComponent(environmentLightingWeight: 1))
        mirror.position.y = mirrorSize.y / 2
        mirror.position.z = -0.05
        entity.position.z = mirror.position.z - 0.05

        let occlusionMaterial = OcclusionMaterial()
        let occlusionLeft = ModelEntity(mesh: .generatePlane(width: mirrorSize.x,  height: mirrorSize.y), materials: [occlusionMaterial])
        occlusionLeft.transform = Transform(rotation: .init(angle: -.pi / 2, axis: .init(0, 1, 0)), translation: .init(-mirrorSize.x / 2, mirror.position.y, mirror.position.z  - mirrorSize.x / 2))
        let occlusionRight = ModelEntity(mesh: .generatePlane(width: mirrorSize.x,  height: mirrorSize.y), materials: [occlusionMaterial])
        occlusionRight.transform = Transform(rotation: .init(angle: .pi / 2, axis: .init(0, 1, 0)), translation: .init(mirrorSize.x / 2, mirror.position.y, mirror.position.z  - mirrorSize.x / 2))
        let occlusionTop = ModelEntity(mesh: .generatePlane(width: mirrorSize.x, depth: mirrorSize.x), materials: [occlusionMaterial])
        occlusionTop.transform = Transform(translation: .init(0, mirrorSize.y, mirror.position.z  - mirrorSize.x / 2))

        root = Entity()
        [mirror, entity, occlusionLeft, occlusionRight, occlusionTop].forEach {
            root.addChild($0)
        }

        entity.children.compactMap {$0 as? ModelEntity}.forEach {
            $0.components.set(ModelSortGroupComponent(group: sortGroup, order: 10))
        }
        mirror.components.set(ModelSortGroupComponent(group: sortGroup, order: 0))

        MirrorSystem.registerSystem()
    }
}

struct MirrorReceiverComponent: Component {
    weak var original: Entity?
}
struct MirrorSystem: System {
    static let query: EntityQuery = .init(where: .has(MirrorReceiverComponent.self))
    init(scene: RealityKit.Scene) {}
    func update(context: SceneUpdateContext) {
        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { e in
            guard let originalTransform = e.components[MirrorReceiverComponent.self]!.original?.convert(transform: .identity, to: nil) else { return }
            e.transform.rotation = .init(angle: .pi, axis: .init(0, 1, 0)) * originalTransform.rotation.inverse
        }
    }
}
