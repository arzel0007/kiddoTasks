import UIKit

/// Small in-memory decode cache so avatar/photo `Data` isn't re-decoded
/// on every SwiftUI body pass.
enum KiddoImageCache {
    private static let cache = NSCache<NSData, UIImage>()

    static func image(from data: Data) -> UIImage? {
        let key = data as NSData
        if let hit = cache.object(forKey: key) {
            return hit
        }
        guard let image = UIImage(data: data) else { return nil }
        // Cap cost roughly by pixel count; avatars are small after compress.
        cache.setObject(image, forKey: key, cost: max(1, Int(image.size.width * image.size.height)))
        return image
    }
}
