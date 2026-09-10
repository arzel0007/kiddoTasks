import SwiftUI
import UIKit

/// Resizes and compresses images so they stay small in the family snapshot.
enum ImageCompressor {
    /// Maximum dimension (width or height) for stored images.
    static let maxDimension: CGFloat = 400
    /// JPEG compression quality (0.0–1.0).
    static let quality: CGFloat = 0.6

    /// Compress a UIImage to JPEG data, scaling down if needed.
    /// Fixes orientation so HEIC/camera photos encode as upright JPEG.
    static func compress(_ image: UIImage) -> Data? {
        let oriented = normalized(image)
        let resized = resize(oriented, to: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Resize an image so its longest edge equals `maxDimension`, preserving aspect ratio.
    private static func resize(_ image: UIImage, to maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let longest = max(size.width, size.height)
        guard longest > maxDimension else {
            return image
        }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

