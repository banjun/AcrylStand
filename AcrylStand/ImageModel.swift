import Foundation
import UniformTypeIdentifiers
import PhotosUI
import Observation

@Observable final class ImageModel {
    init(imageData: Data? = nil) {
        self.selectedImage = imageData
    }
    var isTargeted: Bool = false
    @ObservationIgnored var selectedPickerItems: [PhotosPickerItem] = [] {
        didSet { Task { await moveSelectedPickerItemsIntoImages() }}
    }
    var images: [Data] = [
        try! Data(contentsOf: Bundle.main.url(forResource: "banjun-arisu-v2.psd", withExtension: "png")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "gakumas-arisu", withExtension: "png")!),
    ]
    var selectedImage: Data?
    var maskedImage: CIImage?
    var leggedImage: CIImage?

    func moveSelectedPickerItemsIntoImages() async {
        let items = selectedPickerItems.reversed()
        selectedPickerItems.removeAll()
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            images.insert(data, at: 0)
        }
    }

    func generateMaskImage(legSizeRatio: CGFloat? = 0.2) {
        guard let image = (selectedImage.flatMap {UIImage(data: $0)}) else {
            maskedImage = nil
            return
        }

        let canvasSize = CGSize(width: max(image.size.width, image.size.height), height: max(image.size.width, image.size.height))
        let blend = CIFilter.blendWithAlphaMask()
        blend.backgroundImage = CIImage(color: .black).cropped(to: .init(origin: .zero, size: canvasSize))
        blend.inputImage = CIImage(color: .white).cropped(to: .init(origin: .zero, size: canvasSize))
        blend.maskImage = CIImage(image: image)?.transformed(by: .init(translationX: (canvasSize.width - image.size.width) / 2, y: (canvasSize.height - image.size.height) / 2))
        let morphMax = CIFilter.morphologyMaximum()
        morphMax.radius = 50
        let morphMin = CIFilter.morphologyMinimum()
        morphMin.radius = 10
        let morphMax2 = CIFilter.morphologyMaximum()
        morphMax2.radius = 10
        let morphMin2 = CIFilter.morphologyMinimum()
        morphMin2.radius = 1 // > 0 value helps edge process

        // patterns:
        // blend -> morphs -> masked
        // blend -> leg -> morphs -> masked

        func morph(inputImage: CIImage?) -> CIImage? {
            morphMax.inputImage = inputImage
            morphMin.inputImage = morphMax.outputImage?.cropped(to: .init(origin: .zero, size: canvasSize))
            morphMax2.inputImage = morphMin.outputImage?.cropped(to: .init(origin: .zero, size: canvasSize))
            morphMin2.inputImage = morphMax2.outputImage?.cropped(to: .init(origin: .zero, size: canvasSize))
            return morphMin2.outputImage
        }

        maskedImage = morph(inputImage: blend.outputImage)

        leggedImage = legSizeRatio.flatMap { legSizeRatio in
            let legSize = CGSize(width: canvasSize.width * legSizeRatio, height: canvasSize.height * legSizeRatio)
            let leg = CIFilter.sourceOverCompositing()
            leg.backgroundImage = blend.outputImage
            leg.inputImage = CIImage(color: .white).cropped(to: .init(x: (canvasSize.width - legSize.width) / 2, y: 0, width: legSize.width, height: legSize.height))
            return morph(inputImage: leg.outputImage)
        }
    }
}

import SwiftUI
extension Image {
    init(ciImage: CIImage) {
        self.init(uiImage: UIGraphicsImageRenderer(size: ciImage.extent.size).image { c in
            UIImage(ciImage: ciImage).draw(in: ciImage.extent)
        })
    }
}
