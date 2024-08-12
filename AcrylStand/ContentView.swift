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
                        Text("TODO: preview")
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
