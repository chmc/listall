import SwiftUI

// MARK: - Image Management
extension ItemEditViewModel {
    func addImage(_ itemImage: ItemImage) {
        var newImage = itemImage
        newImage.orderNumber = images.count
        images.append(newImage)
    }

    func removeImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)

        // Reorder remaining images
        for i in 0..<images.count {
            images[i].orderNumber = i
        }
    }

    func moveImage(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < images.count &&
              destinationIndex >= 0 && destinationIndex < images.count &&
              sourceIndex != destinationIndex else { return }

        let movedImage = images.remove(at: sourceIndex)
        images.insert(movedImage, at: destinationIndex)

        // Update order numbers
        for i in 0..<images.count {
            images[i].orderNumber = i
        }
    }
}
