import SwiftUI
import RealityKit

struct AcrylStand: View {
    @State private var controlVisibility: Visibility = .automatic

    var body: some View {
        RealityView { content in
            let scene = try! await Entity(named: "AcrylStand")
            content.add(scene)
        }
        .onTapGesture {
            controlVisibility = switch controlVisibility {
            case .automatic, .visible: .hidden
            case .hidden: .visible
            }
        }
        .persistentSystemOverlays(controlVisibility)
    }
}
