import SwiftUI

struct FullScreenImageView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: imageURL) { phase in
                phase.image?
                    .resizable()
                    .scaledToFit()
                    .gesture(
                        MagnificationGesture()
                            .onEnded { _ in }
                    )
            }
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .padding()
                }
            }
        }
    }
}
