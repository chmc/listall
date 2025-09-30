import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

// MARK: - Image Source Options
enum ImageSource {
    case camera
    case photoLibrary
}

// MARK: - Enhanced Image Picker View
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    let sourceType: ImageSource
    
    init(selectedImage: Binding<UIImage?>, sourceType: ImageSource = .photoLibrary) {
        self._selectedImage = selectedImage
        self.sourceType = sourceType
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        switch sourceType {
        case .camera:
            return makeCameraController(context: context)
        case .photoLibrary:
            return makePhotoLibraryController(context: context)
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Camera Controller
    private func makeCameraController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Show alert to inform user, then fall back to photo library
            let alert = UIAlertController(
                title: "Camera Not Available",
                message: "Camera is not available on this device. Using photo library instead.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                // Present photo library after alert is dismissed
                let photoLibraryController = self.makePhotoLibraryController(context: context)
                alert.presentingViewController?.present(photoLibraryController, animated: true)
            })
            return alert
        }
        
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    // MARK: - Photo Library Controller
    private func makePhotoLibraryController(context: Context) -> UIViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        // MARK: - PHPickerViewControllerDelegate (Photo Library)
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else {
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            return
                        }
                        self?.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
        
        // MARK: - UIImagePickerControllerDelegate (Camera)
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            // Prefer edited image if available, otherwise use original
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            
            DispatchQueue.main.async {
                self.parent.selectedImage = image
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Image Source Selection View
struct ImageSourceSelectionView: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var imageSource: ImageSource = .photoLibrary
    @State private var showingCameraPicker = false
    @State private var showingPhotoLibraryPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Photo")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Camera Option
                    Button(action: {
                        requestCameraPermissionAndOpen()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Take Photo")
                                    .font(.headline)
                                Text("Use camera to take a new photo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    
                    // Photo Library Option
                    Button(action: {
                        showingPhotoLibraryPicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading) {
                                Text("Choose from Library")
                                    .font(.headline)
                                Text("Select from your photo library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCameraPicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingPhotoLibraryPicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
    }
    
    // MARK: - Camera Permission Request
    private func requestCameraPermissionAndOpen() {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthStatus {
        case .authorized:
            openCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.openCamera()
                    } else {
                        self.showPermissionDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert()
        @unknown default:
            showPermissionDeniedAlert()
        }
    }
    
    private func openCamera() {
        showingCameraPicker = true
    }
    
    private func showPermissionDeniedAlert() {
        // Fall back to photo library if camera permission denied
        showingPhotoLibraryPicker = true
    }
}

#Preview {
    ImagePickerView(selectedImage: .constant(nil))
}
