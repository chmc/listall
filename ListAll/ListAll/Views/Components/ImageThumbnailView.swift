import SwiftUI

struct ImageThumbnailView: View {
    let itemImage: ItemImage
    let onDelete: () -> Void
    @StateObject private var imageService = ImageService.shared
    @State private var showingDeleteAlert = false
    @State private var showingFullImage = false
    
    var body: some View {
        ZStack {
            // Thumbnail Image with tap gesture
            if let thumbnail = imageService.swiftUIThumbnail(from: itemImage) {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(Theme.CornerRadius.md)
                    .onTapGesture {
                        showingFullImage = true
                    }
            } else {
                // Placeholder for invalid image
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.Colors.groupedBackground)
                    .frame(width: 100, height: 100)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .foregroundColor(Theme.Colors.secondary)
                                .font(.title2)
                            Text("Invalid")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondary)
                        }
                    )
                    .onTapGesture {
                        showingFullImage = true
                    }
            }
            
            // Delete Button - positioned on top with gesture that prevents propagation
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.red)
                            .clipShape(Circle())
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                // This prevents the underlying tap gesture from firing
                            }
                    )
                    .padding(4)
                }
                Spacer()
            }
        }
        .alert("Delete Image?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showingFullImage) {
            FullImageView(itemImage: itemImage)
        }
    }
}

// MARK: - Full Image View
struct FullImageView: View {
    let itemImage: ItemImage
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageService = ImageService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = imageService.swiftUIImage(from: itemImage) {
                    ZoomableImageView(image: image)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                            .font(.system(size: 60))
                        Text("Unable to load image")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.top)
                    }
                }
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let image: Image
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main zoomable image
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .onAppear {
                        containerSize = geometry.size
                        // Calculate initial fit-to-screen scale
                        resetToFitScreen()
                    }
                    .onChange(of: geometry.size) { newSize in
                        containerSize = newSize
                        resetToFitScreen()
                    }
                    .gesture(
                        SimultaneousGesture(
                            // Magnification gesture for zooming
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = max(minScale, min(maxScale, newScale))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // Snap to fit if close to 1.0
                                    if abs(scale - 1.0) < 0.1 {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                },
                            
                            // Drag gesture for panning
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = constrainOffset(newOffset)
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    // Double tap to zoom in/out
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if scale > 1.5 {
                                // Zoom out to fit
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                // Zoom in to 2x
                                scale = 2.0
                                lastScale = 2.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetToFitScreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    private func constrainOffset(_ newOffset: CGSize) -> CGSize {
        // Calculate the maximum allowed offset based on current scale
        let scaledImageWidth = containerSize.width * scale
        let scaledImageHeight = containerSize.height * scale
        
        let maxOffsetX = max(0, (scaledImageWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledImageHeight - containerSize.height) / 2)
        
        let constrainedX = max(-maxOffsetX, min(maxOffsetX, newOffset.width))
        let constrainedY = max(-maxOffsetY, min(maxOffsetY, newOffset.height))
        
        return CGSize(width: constrainedX, height: constrainedY)
    }
}

// MARK: - Image Gallery View (for ItemDetailView)
struct ImageGalleryView: View {
    let images: [ItemImage]
    @StateObject private var imageService = ImageService.shared
    @State private var selectedImageIndex: Int?
    
    var body: some View {
        if images.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Header with image count and info
                HStack {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "photo.stack")
                            .foregroundColor(Theme.Colors.primary)
                            .font(.title3)
                        Text("Images")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Spacer()
                    
                    // Image count badge
                    Text("\(images.count)")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.primary)
                        .clipShape(Capsule())
                }
                
                // Horizontal scrolling gallery
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.Spacing.md) {
                        ForEach(images.indices, id: \.self) { index in
                            ImageThumbnailCard(
                                itemImage: images[index],
                                index: index,
                                imageService: imageService
                            ) {
                                selectedImageIndex = index
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                
                // Helpful tip for first-time users
                if images.count == 1 {
                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundColor(Theme.Colors.secondary)
                            .font(.caption)
                        Text("Tap image to view full size")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
            }
            .sheet(item: Binding<Int?>(
                get: { selectedImageIndex },
                set: { selectedImageIndex = $0 }
            )) { index in
                FullImageView(itemImage: images[index])
            }
        }
    }
}

// MARK: - Image Thumbnail Card
struct ImageThumbnailCard: View {
    let itemImage: ItemImage
    let index: Int
    let imageService: ImageService
    let onTap: () -> Void
    
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Theme.Colors.groupedBackground)
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Image content
            Group {
                if let thumbnail = imageService.swiftUIThumbnail(from: itemImage) {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(Theme.CornerRadius.md)
                        .onAppear {
                            isLoading = false
                        }
                } else {
                    // Placeholder with loading state
                    VStack(spacing: Theme.Spacing.xs) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Theme.Colors.primary)
                        } else {
                            Image(systemName: "photo")
                                .foregroundColor(Theme.Colors.secondary)
                                .font(.title2)
                            Text("Invalid")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.secondary)
                        }
                    }
                    .onAppear {
                        // Simulate loading delay for better UX
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isLoading = false
                        }
                    }
                }
            }
            
            // Index overlay for multiple images
            if index < 9 { // Only show for first 9 images to avoid clutter
                VStack {
                    HStack {
                        Spacer()
                        Text("\(index + 1)")
                            .font(Theme.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Binding Extension for Sheet
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview("Image Thumbnail") {
    let sampleImage = ItemImage(imageData: UIImage(systemName: "photo")?.pngData())
    return ImageThumbnailView(itemImage: sampleImage) {
        print("Delete tapped")
    }
}

#Preview("Image Gallery") {
    let sampleImages = [
        ItemImage(imageData: UIImage(systemName: "photo")?.pngData()),
        ItemImage(imageData: UIImage(systemName: "camera")?.pngData()),
        ItemImage(imageData: UIImage(systemName: "heart")?.pngData())
    ]
    return ImageGalleryView(images: sampleImages)
}
