import SwiftUI

struct ImageThumbnailView: View {
    let itemImage: ItemImage
    let onDelete: () -> Void
    @StateObject private var imageService = ImageService.shared
    @State private var showingDeleteAlert = false
    @State private var showingFullImage = false
    
    var body: some View {
        ZStack {
            // Thumbnail Image
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
            }
            
            // Delete Button
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
                    ScrollView([.horizontal, .vertical]) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .clipped()
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

// MARK: - Image Gallery View (for ItemDetailView)
struct ImageGalleryView: View {
    let images: [ItemImage]
    @StateObject private var imageService = ImageService.shared
    @State private var selectedImageIndex: Int?
    
    var body: some View {
        if images.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "photo.stack")
                        .foregroundColor(Theme.Colors.primary)
                    Text("Images (\(images.count))")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primary)
                    Spacer()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.Spacing.sm) {
                        ForEach(images.indices, id: \.self) { index in
                            if let thumbnail = imageService.swiftUIThumbnail(from: images[index]) {
                                thumbnail
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(Theme.CornerRadius.sm)
                                    .onTapGesture {
                                        selectedImageIndex = index
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.groupedBackground)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(Theme.Colors.secondary)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
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
