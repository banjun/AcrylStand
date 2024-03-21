import SwiftUI

@main
struct AcrylStandApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView(onDropImage: { image in
                guard let data = image.pngData() else { return }
                // TODO: use either of these
                openWindow(id: "Image", value: data)
                openWindow(id: "FixedImage", value: data)
            })
        }
        .defaultSize(width: 300, height: 300)
        .windowResizability(.contentMinSize)

        // dynamic scale window (placing far position let it bigger physically)
        WindowGroup(id: "Image", for: Data.self) { $value in
            if let value, let image = UIImage(data: value) {
                WindowSceneReader { windowScene, window in
                    ImageView(image: image)
                        .onChange(of: window) { updateWindowAspectRatio(windowScene: windowScene, size: image.size) }
                }
            } else {
                Text("Error in decoding image")
            }
        }
        .windowStyle(.plain) // make background transparent (default is plain with glass background effect)

        // fixed scale window (placing far position let it smaller but still same size physically)
        WindowGroup(id: "FixedImage", for: Data.self) { $value in
            ZStack {
                // TODO: make the image front aligned
                Spacer().frame(depth: 150)
                if let value, let image = UIImage(data: value) {
                    // TODO: 1. calculate a good default physical size
                    // TODO: 2. ui for changing size
                    // upper limit seems to be around 2700pt
                    let maxSide: CGFloat = 2700
                    let aspect = min(1, min(maxSide / image.size.width, maxSide / image.size.height))
                    let width = image.size.width * aspect
                    let height = image.size.height * aspect
                    ImageView(image: image)
                        .frame(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)
                } else {
                    Text("Error in decoding image")
                }
            }
        }
        .defaultSize(width: 150, height: 150, depth: 150) // lower limit seems to be around 150pt
        .windowStyle(.volumetric)
        .windowResizability(.contentMinSize)
    }

    private func updateWindowAspectRatio(windowScene: () -> UIWindowScene?, size: CGSize) {
        guard let windowScene = windowScene() else { return }
        // .uniform fixes aspect ratio to the current window size.
        // for example, set to 3840x2160 may fail due to large height for the space.
        // in the case above, .uniform fixes aspect to the failed result size.
        // as a workaround, scale down prior to set window size
        let height = min(size.height, 1080)
        let width = size.width * height / size.height
        windowScene.requestGeometryUpdate(.Vision(size: .init(width: width, height: height), resizingRestrictions: .uniform))
    }
}
