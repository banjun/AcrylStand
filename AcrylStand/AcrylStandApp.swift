import SwiftUI

#if DEBUG
import SwiftHotReload
extension AcrylStandApp {
//    static let reloader = StandaloneReloader(monitoredSwiftFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("RuntimeOverride.swift"))
    static let reloader = ProxyReloader(.init(targetSwiftFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("RuntimeOverride.swift")))
}
#endif

import PhotosUI

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
        }
        .defaultSize(width: 300, height: 300)
        .windowResizability(.contentSize)

        // dynamic scale window (placing far position let it bigger physically)
        WindowGroup(id: "Image", for: Data.self) { $value in
            if let value {
//                WindowSceneReader { windowScene, window in
                ImageView()
                    .environment(ImageModel(imageData: value))
//                        .onChange(of: window) { updateWindowAspectRatio(windowScene: windowScene, size: image.size) }
//                }
            } else {
                Text("Error in decoding image")
            }
        }
        .windowStyle(.plain) // make background transparent (default is plain with glass background effect)

        let minVolumetricLength: CGFloat = 300 // lower limit seems to be around 300pt
        let maxVolumetricLength: CGFloat = 2700 // upper limit seems to be around 2700pt
        // fixed scale window (placing far position let it smaller but still same size physically)
        WindowGroup(id: "FixedImage", for: Data.self) { $value in
            FixedSizeImage(imageModel: ImageModel(imageData: value), minVolumetricLength: minVolumetricLength, maxVolumetricLength: maxVolumetricLength)
                .handlesExternalEvents(preferring: [], allowing: []) // causes the main window active on re-opening the app, or open a main window), without activating this group.
        }
        .defaultSize(width: minVolumetricLength, height: minVolumetricLength, depth: minVolumetricLength)
        .windowStyle(.volumetric)
        .windowResizability(.contentSize)
        .volumeWorldAlignmentGravityAligned()

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


struct FixedSizeImage: View {
    let imageModel: ImageModel
    let minVolumetricLength: CGFloat
    let maxVolumetricLength: CGFloat
    @Environment(\.physicalMetrics) private var physicalMetrics
    @State private var heightInCM: CGFloat = 30

    var body: some View {
        ZStack {
            // make the image front aligned within lower depth limit
//            Spacer().frame(depth: minVolumetricLength)
            if let image = imageModel.leggedImage {
                // TODO: 1. calculate a good default physical size
                // TODO: 2. ui for changing size
                let aspect = image.extent.size.width / image.extent.size.height
                let height = physicalMetrics.convert(heightInCM, from: .centimeters)
                let width = height * aspect
                ImageView()
                    .environment(imageModel)
                    .frame(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)
                    .frame(minDepth: width, maxDepth: width)
            } else {
                ProgressView().onAppear {
                    imageModel.generateMaskImage()
                }
            }
        }
    }
}

extension Scene {
    func volumeWorldAlignmentGravityAligned() -> some Scene {
        if #available(visionOS 2, *) {
            return volumeWorldAlignment(.gravityAligned)
        } else {
            return self
        }
    }
}
extension View {
    func volumeBaseplateDisabled() -> some View {
        if #available(visionOS 2, *) {
            return volumeBaseplateVisibility(.hidden)
        } else {
            return self
        }
    }
}
