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
        case emptyData
        case uploadFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Cloud storage isn’t available on this build."
            case .notSignedIn:
                return "Sign in to sync photos to the cloud."
            case .emptyData:
                return "That image couldn’t be prepared for upload."
            case .uploadFailed(let message):
                return "Couldn’t upload photo. \(message)"
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
    /// `itemId` must be the **stable** child/family id (not a throwaway UUID).
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
        guard !data.isEmpty else {
            throw PhotoStorageError.emptyData
        }
        guard !familyId.isEmpty, !itemId.isEmpty else {
            throw PhotoStorageError.uploadFailed("Missing family or item id.")
        }

        let path = "families/\(familyId)/\(kind.folder)/\(itemId).jpg"
        let ref = Storage.storage().reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
        } catch {
            print("[Photo] putData failed path=\(path) \(error.localizedDescription)")
            throw PhotoStorageError.uploadFailed(friendlyStorageMessage(error))
        }

        do {
            let url = try await ref.downloadURL()
            print("[Photo] uploaded \(path) → \(url.absoluteString.prefix(80))…")
            return url.absoluteString
        } catch {
            print("[Photo] downloadURL failed: \(error.localizedDescription)")
            throw PhotoStorageError.uploadFailed(friendlyStorageMessage(error))
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

    /// Maps common Storage failures to parent-readable copy.
    private static func friendlyStorageMessage(_ error: Error) -> String {
        let ns = error as NSError
        let text = ns.localizedDescription.lowercased()
        if text.contains("bucket") || text.contains("object-not-found") && text.contains("bucket") {
            return "Storage isn’t set up in Firebase yet. Enable Storage in the console, then deploy rules."
        }
        // StorageErrorObjectNotFound / missing bucket often surfaces as -13010 etc.
        if ns.domain.contains("FIRStorageErrorDomain") {
            if text.contains("does not exist") || text.contains("no bucket") {
                return "Firebase Storage bucket is missing. Enable Storage in the Firebase console."
            }
            if text.contains("unauthorized") || text.contains("permission") {
                return "Storage rules blocked the upload. Deploy Firebase/storage.rules."
            }
        }
        if text.contains("network") || text.contains("offline") {
            return "Network error while uploading. Try again when you’re online."
        }
        return error.localizedDescription
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
                print("[Photo] remote load failed: \(error.localizedDescription)")
            }
        }
    }
}
