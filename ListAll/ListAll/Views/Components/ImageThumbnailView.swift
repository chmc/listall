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
    let images: [ItemImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageService = ImageService.shared
    @State private var currentIndex: Int
    
    init(itemImage: ItemImage) {
        self.images = [itemImage]
        self.initialIndex = 0
        self._currentIndex = State(initialValue: 0)
    }
    
    init(images: [ItemImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = min(max(initialIndex, 0), images.count - 1)
        self._currentIndex = State(initialValue: min(max(initialIndex, 0), images.count - 1))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if images.isEmpty {
                    VStack {
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                            .font(.system(size: 60))
                        Text("No images to display")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.top)
                    }
                } else if images.count == 1 {
                    // Single image - no page view needed
                    if let uiImage = images[0].uiImage,
                       let swiftUIImage = imageService.swiftUIImage(from: images[0]) {
                        ZoomableImageView(image: swiftUIImage, uiImage: uiImage)
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
                } else {
                    // Multiple images - use TabView for swipe navigation
                    TabView(selection: $currentIndex) {
                        ForEach(images.indices, id: \.self) { index in
                            if let uiImage = images[index].uiImage,
                               let swiftUIImage = imageService.swiftUIImage(from: images[index]) {
                                ZoomableImageView(image: swiftUIImage, uiImage: uiImage)
                                    .tag(index)
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
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                }
            }
            .navigationTitle(images.count > 1 ? "Image \(currentIndex + 1) of \(images.count)" : "Image")
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

// MARK: - Zoomable Image View (UIScrollView-based - iOS Best Practice)
struct ZoomableImageView: View {
    let image: Image
    let uiImage: UIImage?
    
    init(image: Image, uiImage: UIImage? = nil) {
        self.image = image
        self.uiImage = uiImage
    }
    
    var body: some View {
        if let uiImage = uiImage {
            ZoomableScrollView(uiImage: uiImage)
        } else {
            // Fallback: show error
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.yellow)
                    .font(.system(size: 60))
                Text("Image data unavailable")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top)
            }
        }
    }
}

// MARK: - UIScrollView Wrapper (Native iOS Zooming)
struct ZoomableScrollView: UIViewRepresentable {
    let uiImage: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        
        // Create UIImageView
        let imageView = UIImageView(image: uiImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        
        // Use AutoLayout with layout guides (proven Apple pattern)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        // Add double-tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // No need to update - AutoLayout handles sizing
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableScrollView
        
        init(_ parent: ZoomableScrollView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            
            // If already zoomed in, zoom back to 1.0
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                // Zoom in to 2x at tap location
                let pointInView = gesture.location(in: scrollView)
                let scrollViewSize = scrollView.bounds.size
                let w = scrollViewSize.width / 2.0
                let h = scrollViewSize.height / 2.0
                let x = pointInView.x - (w / 2.0)
                let y = pointInView.y - (h / 2.0)
                let rectToZoomTo = CGRect(x: x, y: y, width: w, height: h)
                scrollView.zoom(to: rectToZoomTo, animated: true)
            }
        }
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
                FullImageView(images: images, initialIndex: index)
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

// MARK: - Draggable Image Thumbnail View (for Edit Mode)
struct DraggableImageThumbnailView: View {
    let itemImage: ItemImage
    let index: Int
    let totalImages: Int
    let onDelete: () -> Void
    let onMove: (Int, Int) -> Void
    
    @StateObject private var imageService = ImageService.shared
    @State private var showingDeleteAlert = false
    @State private var showingFullImage = false
    
    var body: some View {
        VStack(spacing: 4) {
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
                
                // Delete Button - top right
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
                
                // Index indicator (top-left)
                VStack {
                    HStack {
                        Text("\(index + 1)")
                            .font(Theme.Typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(4)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Move buttons (left/right arrows)
            if totalImages > 1 {
                HStack(spacing: 8) {
                    // Move left button
                    Button(action: {
                        if index > 0 {
                            HapticManager.shared.trigger(.selection)
                            onMove(index, index - 1)
                        }
                    }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .foregroundColor(index > 0 ? .blue : .gray.opacity(0.3))
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(index == 0)
                    
                    // Move right button
                    Button(action: {
                        if index < totalImages - 1 {
                            HapticManager.shared.trigger(.selection)
                            onMove(index, index + 1)
                        }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(index < totalImages - 1 ? .blue : .gray.opacity(0.3))
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(index == totalImages - 1)
                }
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

// MARK: - Binding Extension for Sheet
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview("Image Thumbnail") {
    let sampleImage = ItemImage(imageData: UIImage(systemName: "photo")?.pngData())
    return ImageThumbnailView(itemImage: sampleImage) {
        // Delete action
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
