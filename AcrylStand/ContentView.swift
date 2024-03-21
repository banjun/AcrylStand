import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var onDropImage: (UIImage) -> Void = {_ in}
    @State private var isTargeted: Bool = false

    var body: some View {
        Color.white.opacity(0.3)
            .overlay {
                Text("Drop Image")
            }
            .clipShape(RoundedRectangle(cornerSize: .init(width: 60, height: 60)))
            .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
                _ = providers.first?.loadDataRepresentation(for: .image) { data, _ in
                    guard let data, let image = UIImage(data: data) else { return }
                    Task { @MainActor in
                        onDropImage(image)
                    }
                }
                return true
            }
            .padding(isTargeted ? 20 : 40)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
