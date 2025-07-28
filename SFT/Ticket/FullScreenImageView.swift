import SwiftUI
import Photos

import SwiftUI

struct FullScreenImageView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss

    var doubleTapScale: CGFloat = 2.0
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 4.0
    var dragThreshold: CGFloat = 80.0
    var onDragEnd: ((SwipeDirection) -> Void)? = nil

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragDirection: SwipeDirection = .none

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(simultaneousGestures(geo: geo))
                            .animation(.interactiveSpring(), value: scale)
                            .animation(.interactiveSpring(), value: offset)
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if abs(scale - minScale) < 0.01 {
                                        scale = doubleTapScale
                                    } else {
                                        scale = minScale
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                    lastScale = scale
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }

                // 关闭按钮
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(20)
            }
        }
    }

    func simultaneousGestures(geo: GeometryProxy) -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard scale > minScale else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    dragDirection = detectDragDirection(value.translation)
                }
                .onEnded { value in
                    guard scale > minScale else {
                        let translation = value.translation
                        let maxDist = max(abs(translation.width), abs(translation.height))
                        if maxDist > dragThreshold {
                            onDragEnd?(detectDragDirection(translation))
                        }
                        return
                    }
                    lastOffset = offset
                    withAnimation { clampOffset(in: geo.size) }
                },

            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                }
                .onEnded { _ in
                    if scale < minScale {
                        scale = minScale
                        offset = .zero
                        lastOffset = .zero
                    } else if scale > maxScale {
                        scale = maxScale
                    }
                    lastScale = scale
                    withAnimation { clampOffset(in: geo.size) }
                }
        )
    }

    func detectDragDirection(_ translation: CGSize) -> SwipeDirection {
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }

    func clampOffset(in screenSize: CGSize) {
        let maxOffsetX = ((screenSize.width * scale) - screenSize.width) / 2
        let maxOffsetY = ((screenSize.height * scale) - screenSize.height) / 2

        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)

        lastOffset = offset
    }
}

enum SwipeDirection {
    case up, down, left, right, none
}
