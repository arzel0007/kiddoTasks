import Foundation
import UIKit
import Observation
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Uploads profile photos to Firebase Storage so the family snapshot stays small.
/// Local `photoData` remains for instant offline UI; cloud uses `photoURL`.
enum FamilyPhotoStorage {
    enum PhotoStorageError: LocalizedError {
        case notConfigured
        case notSignedIn
        case uploadFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Cloud storage isn't available right now."
            case .notSignedIn: return "Sign in to sync photos."
            case .uploadFailed(let message): return "Couldn't upload photo. \(message)"
            }
        }
    }

    enum Kind {
        case child
        case family

        var folder: String {
            switch self {
            case .child: return "children"
            case .family: return "family"
            }
        }
    }

    /// Uploads JPEG data under `families/{familyId}/...` and returns a download URL.
    static func uploadPhoto(
        familyId: String,
        kind: Kind,
        itemId: String,
        data: Data
    ) async throws -> String {
        #if canImport(FirebaseStorage) && canImport(FirebaseAuth)
        guard Auth.auth().currentUser != nil else {
            throw PhotoStorageError.notSignedIn
        }
        let path = "families/\(familyId)/\(kind.folder)/\(itemId).jpg"
        let ref = Storage.storage().reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<StorageMetadata, Error>) in
                ref.putData(data, metadata: metadata) { metadata, error in
                    if let error {
                        cont.resume(throwing: PhotoStorageError.uploadFailed(error.localizedDescription))
                    } else if let metadata {
                        cont.resume(returning: metadata)
                    } else {
                        cont.resume(throwing: PhotoStorageError.uploadFailed("No metadata"))
                    }
                }
            }
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch let error as PhotoStorageError {
            throw error
        } catch {
            throw PhotoStorageError.uploadFailed(error.localizedDescription)
        }
        #else
        throw PhotoStorageError.notConfigured
        #endif
    }

    static func deletePhoto(familyId: String, kind: Kind, itemId: String) async {
        #if canImport(FirebaseStorage)
        let path = "families/\(familyId)/\(kind.folder)/\(itemId).jpg"
        try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Storage.storage().reference(withPath: path).delete { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
        #endif
    }
}

/// Lightweight async image loader for Storage download URLs.
@MainActor
@Observable
final class RemotePhotoLoader {
    var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()
    private var currentURL: String?

    func load(urlString: String) {
        guard currentURL != urlString else { return }
        currentURL = urlString

        if let cached = Self.cache.object(forKey: urlString as NSString) {
            image = cached
            return
        }

        guard let url = URL(string: urlString) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard currentURL == urlString else { return }
                if let uiImage = UIImage(data: data) {
                    Self.cache.setObject(uiImage, forKey: urlString as NSString)
                    image = uiImage
                }
            } catch {
                // Leave placeholder; avatar emoji still shows.
            }
        }
    }
}
