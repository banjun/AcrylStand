import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import Observation

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    var onDropImage: (UIImage) -> Void = {_ in}
    private let imageModel = ImageModel()

    var body: some View {
        @Bindable var imageModel = imageModel
        ScrollView(.horizontal) {
            HStack(alignment: .center) {
                ForEach(imageModel.images, id: \.self) { data in
                    Button {
                        imageModel.selectedImage = data
                        imageModel.generateMaskImage()
                    } label: {
                        Image(uiImage: UIImage(data: data) ?? UIImage()).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128, alignment: .center)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .buttonBorderShape(.roundedRectangle)
                }
            }
        }
        .frame(height: 128)
        .padding()

        PhotosPicker(selection: $imageModel.selectedPickerItems, matching: .images, preferredItemEncoding: .current) {
            Text("Image Picker")
        }

        if let data = imageModel.selectedImage, let image = UIImage(data: data) {
            VStack(alignment: .leading) {
                Text("Process")
                ScrollView(.horizontal) {
                    HStack(alignment: .top) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                        Image(systemName: "arrow.right").padding()
                        if let image = imageModel.maskedImage {
                            Image(ciImage: image).resizable().aspectRatio(contentMode: .fit)
                        } else { ProgressView() }
                        Image(systemName: "arrow.right").padding()
                        if let image = imageModel.leggedImage {
                            Image(ciImage: image).resizable().aspectRatio(contentMode: .fit)
                        } else { ProgressView() }
                        Image(systemName: "arrow.right").padding()
                        PortalDisplay(imageModel: imageModel)
                            .aspectRatio(1, contentMode: .fit)
//                        FixedSizeImage(imageModel: imageModel, minVolumetricLength: 100, maxVolumetricLength: 100)
                    }
                    .padding()
                }
            }
            .padding()
            .background(.background)
        } else {
            Color.white.opacity(0.3)
                .overlay { Text("Select or Drop Image to create acrylic stand") }
                .clipShape(RoundedRectangle(cornerSize: .init(width: 60, height: 60)))
                .onDrop(of: [.image], isTargeted: $imageModel.isTargeted) { providers in
                    _ = providers.first?.loadDataRepresentation(for: .image) { data, _ in
                        guard let data, let image = UIImage(data: data) else { return }
                        Task { @MainActor in
                            onDropImage(image)
                        }
                    }
                    return true
                }
                .padding(imageModel.isTargeted ? 20 : 40)
        }

        Button("Create Acrylic Stand") {
            openWindow(id: "FixedImage", value: imageModel.selectedImage!)
        }
        .disabled(imageModel.selectedImage == nil)
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}

import RealityKit
import Vision

struct PortalDisplay: View {
    var imageModel: ImageModel
    @State private var path: UIBezierPath?

    var body: some View {
        if let path {
            RealityView { content in
                let world = Entity()
                world.components.set(WorldComponent())

                guard let imageData = imageModel.selectedImage else { return }
                let acrylEntity = try! await AcrylEntity(imageData: imageData, path: path)
//                world.scale = .init(repeating: 0.1)
                world.addChild(acrylEntity)

                let portal = ModelEntity(mesh: .generatePlane(width: 0.1, height: 0.1), materials: [PortalMaterial()])
                portal.position.z = -0.1
                portal.components.set(PortalComponent(target: world))
                content.add(portal)
                content.add(world)
            }
//            .frame(width: 100, height: 100)
        } else {
            ProgressView().onAppear {
                // FIXME: remove copy&paste from another file
                if imageModel.leggedImage == nil {
                    imageModel.generateMaskImage()
                }
                guard let image = imageModel.leggedImage else { return }

                let request = VNDetectContoursRequest { req, error in
                    guard let observation = req.results?.first as? VNContoursObservation else { return }
                    if let error {
                        NSLog("%@", "\(String(describing: error))")
                        path = nil
                        return
                    }

                    guard let maxContour = (observation.topLevelContours.max { $0.pointCount < $1.pointCount }) else { return }
                    let contour = (maxContour.childContours.max { $0.pointCount < $1.pointCount }) ?? maxContour
                    let path = UIBezierPath(cgPath: contour.normalizedPath)
                    path.apply(CGAffineTransform.identity
                               //                    .scaledBy(x: image.extent.width, y: -image.extent.height)
                        .scaledBy(x: 1, y: -1)
                        .translatedBy(x: 0, y: -1))
                    self.path = path
                }
                request.maximumImageDimension = Int(max(image.extent.width, image.extent.height))
                //            request.contrastAdjustment =
                //            request.contrastPivot =
                //            request.detectsDarkOnLight = true
                let handler = VNImageRequestHandler(ciImage: image)
                do {
                    try handler.perform([request])
                } catch {
                    NSLog("%@", "\(String(describing: error))")
                    path = nil
                }
            }
        }
    }
}
