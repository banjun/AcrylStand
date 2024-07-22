import SwiftUI

#if DEBUG
import SwiftHotReload
extension AcrylStandApp {
    static let reloader = StandaloneReloader(monitoredSwiftFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("RuntimeOverride.swift"))
}
#endif

@main
struct AcrylStandApp: App {
#if DEBUG
    @ObservedObject private var reloader = Self.reloader
#endif
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView(onDropImage: { image in
                guard let data = image.pngData() else { return }
                // TODO: use either of these
                openWindow(id: "Image", value: data)
                openWindow(id: "FixedImage", value: data)
            })

            Spacer().frame(height: 40)

            Button("Open Experimental AcrylStand") {
                openWindow(id: "Experimental")
//                openWindow(id: "Image", value: UIImage(named: "banjun-arisu-v2.psd")!.pngData()!)
                openWindow(id: "Experimental2", value: UIImage(named: "banjun-arisu-v2.psd")!.pngData()!)
                openWindow(id: "Experimental2", value: UIImage(named: "gakumas-arisu.heic")!.pngData()!)
            }
            .padding()
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

        let minVolumetricLength: CGFloat = 300 // lower limit seems to be around 300pt
        let maxVolumetricLength: CGFloat = 2700 // upper limit seems to be around 2700pt
        // fixed scale window (placing far position let it smaller but still same size physically)
        WindowGroup(id: "FixedImage", for: Data.self) { $value in
            ZStack {
                // make the image front aligned within lower depth limit
                Spacer().frame(depth: minVolumetricLength)
                if let value, let image = UIImage(data: value) {
                    // TODO: 1. calculate a good default physical size
                    // TODO: 2. ui for changing size
                    let aspect = min(1, min(maxVolumetricLength / image.size.width, maxVolumetricLength / image.size.height))
                    let width = image.size.width * aspect
                    let height = image.size.height * aspect
                    ImageView(image: image)
                        .frame(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)
                } else {
                    Text("Error in decoding image")
                }
            }
        }
        .defaultSize(width: minVolumetricLength, height: minVolumetricLength, depth: minVolumetricLength)
        .windowStyle(.volumetric)
        .windowResizability(.contentSize)

        WindowGroup(id: "Experimental") {
            ZStack {
                // make the image front aligned within lower depth limit
                Spacer().frame(depth: minVolumetricLength)

                AcrylStand()
            }
        }
        .defaultSize(width: minVolumetricLength, height: minVolumetricLength, depth: minVolumetricLength)
        .windowStyle(.volumetric)
        .windowResizability(.contentSize)

        WindowGroup(id: "Experimental2", for: Data.self) { $image in
            ZStack {
                // make the image front aligned within lower depth limit
                Spacer().frame(depth: minVolumetricLength)

                ImageView(image: UIImage(data: image!)!)
            }
        }
        .defaultSize(width: minVolumetricLength, height: minVolumetricLength, depth: minVolumetricLength)
        .windowStyle(.volumetric)
        .windowResizability(.contentSize)
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
