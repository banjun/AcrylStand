import SwiftUI

struct ImageView: View {
    var image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
    }
}
