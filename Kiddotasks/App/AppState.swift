import Foundation
import Observation
import SwiftUI

/// Root application state. Uses the local family store so the app is fully usable
/// on device without Firebase. When Firebase is configured, `cloudSync` takes
/// over authentication and keeps the store synchronized across all devices.
@Observable
@MainActor
final class AppState {
    let store: LocalFamilyDataStore
    let cloudSync: CloudSyncEngine

    var currentChildProfile: Child?
    var interfaceOverride: InterfaceOverride = .automatic
    var authenticationError: String?
    var isLoading: Bool = false
    var errorMessage: String?
    /// Set after a cloud sign-up so the UI can reveal the Kids Station PIN.
    var familyBootstrapPIN: String?

    /// True when the Firebase SDK is linked and configured with a plist.
    var isCloudEnabled: Bool { cloudSync.isAvailable }

    var cloudSyncStatus: CloudSyncStatus { cloudSync.status }

    init() {
        let storeInstance = LocalFamilyDataStore()
        store = storeInstance
        cloudSync = CloudSyncEngine(store: storeInstance)
        cloudSync.start()
    }

    enum InterfaceOverride: String, CaseIterable, Identifiable {
        case automatic
        case parent
        case kids

        var id: String { rawValue }

        var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .parent: return "Parent Center"
            case .kids: return "Kids Station"
            }
        }
    }

    var isAuthenticated: Bool { store.isAuthenticated }
    var currentFamily: Family? { store.family }
    var currentParent: Parent? { store.parent }
    var familyChildren: [Child] { store.children }

    var isIPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    var applicationMode: ApplicationMode {
        if !isAuthenticated {
            return .login
        }
        switch interfaceOverride {
        case .parent:
            return .parentControl
        case .kids:
            return currentChildProfile == nil ? .kidsSelection : .kidsStation
        case .automatic:
            if isIPad {
                return currentChildProfile == nil ? .kidsSelection : .kidsStation
            }
            return .parentControl
        }
    }

    func selectChildProfile(_ child: Child) {
        currentChildProfile = child
    }

    func clearChildProfile() {
        currentChildProfile = nil
    }

    /// Signs up a new family. Uses Firebase when configured (cloud account,
    /// remote family bootstrap, all starter content pushed up), otherwise falls
    /// back to the local-only store so the prototype keeps working unchanged.
    func signUp(
        familyName: String,
        parentName: String,
        email: String,
        password: String,
        completion: (() -> Void)? = nil
    ) {
        authenticationError = nil
        familyBootstrapPIN = nil
        Task { @MainActor in
            if cloudSync.isAvailable {
                do {
                    isLoading = true
                    defer { isLoading = false }
                    let pin = try await cloudSync.signUp(
                        email: email,
                        password: password,
                        familyName: familyName,
                        parentName: parentName
                    )
                    familyBootstrapPIN = pin
                    completion?()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            } else {
                do {
                    try store.signUp(
                        familyName: familyName,
                        parentName: parentName,
                        email: email,
                        password: password
                    )
                    completion?()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            }
        }
    }

    /// Signs in an existing account. With Firebase this pulls the family down
    /// from the cloud — which is exactly what lets an existing user switch
    /// devices and keep their data.
    func signIn(
        email: String,
        password: String,
        completion: (() -> Void)? = nil
    ) {
        authenticationError = nil
        Task { @MainActor in
            if cloudSync.isAvailable {
                do {
                    isLoading = true
                    defer { isLoading = false }
                    try await cloudSync.signIn(email: email, password: password)
                    completion?()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            } else {
                do {
                    try store.signIn(email: email, password: password)
                    completion?()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            }
        }
    }

    /// Join an existing family using a shared family code.
    func joinWithCode(
        code: String,
        email: String,
        password: String,
        completion: (() -> Void)? = nil
    ) {
        authenticationError = nil
        Task { @MainActor in
            do {
                try store.joinFamily(withCode: code, email: email, password: password)
                completion?()
            } catch {
                authenticationError = friendlyAuthError(error)
            }
        }
    }

    func signOut() {
        currentChildProfile = nil
        interfaceOverride = .automatic
        familyBootstrapPIN = nil
        cloudSync.signOut()
    }

    /// Maps low-level auth errors to friendly, actionable messages.
    private func friendlyAuthError(_ error: Error) -> String {
        if let firebaseError = error as? FirebaseError {
            return firebaseError.errorDescription ?? "Something went wrong. Please try again."
        }
        let message = error.localizedDescription.lowercased()
        if message.contains("already") {
            return "An account with this email already exists. Try signing in instead."
        }
        if message.contains("wrong") || message.contains("invalid") || message.contains("incorrect") {
            return "Email or password is incorrect."
        }
        if message.contains("network") || message.contains("offline") || message.contains("internet") {
            return "Can't reach the cloud right now. Check your connection and try again."
        }
        if message.contains("too many") {
            return "Too many attempts. Please wait a moment and try again."
        }
        return error.localizedDescription
    }

    func child(id: String) -> Child? {
        store.children.first { $0.id == id }
    }

    func task(id: String) -> KiddoTask? {
        store.tasks.first { $0.id == id }
    }

    func reward(id: String) -> Reward? {
        store.rewards.first { $0.id == id }
    }

    func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func clearError() {
        errorMessage = nil
    }
}

enum ApplicationMode {
    case login
    case parentControl
    case kidsSelection
    case kidsStation
}
