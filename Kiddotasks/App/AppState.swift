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
    var successMessage: String?
    var isLoading: Bool = false
    var errorMessage: String?
    /// Set after a cloud sign-up so the UI can reveal the Kids Station PIN.
    var familyBootstrapPIN: String?
    /// Kids unlocked this session via PIN (may be without a parent UI session).
    var kidsSessionUnlocked = false
    /// When true, Kids Station opens on the shared Games tab (no child required).
    var gamesTabRequested = false
    /// Where a push notification wants us to go after launch.
    var pendingDeepLink: String?
    /// Set when a notification arrived in foreground/background.
    var lastNotificationRoute: String?

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
            // PIN-unlocked kids session on a shared iPad without a parent sign-in UI.
            if kidsSessionUnlocked, store.family != nil {
                return currentChildProfile == nil ? .kidsSelection : .kidsStation
            }
            return .login
        }
        switch interfaceOverride {
        case .parent:
            return .parentControl
        case .kids:
            if currentChildProfile == nil && !gamesTabRequested {
                return .kidsSelection
            }
            return .kidsStation
        case .automatic:
            if isIPad {
                if currentChildProfile == nil && !gamesTabRequested {
                    return .kidsSelection
                }
                return .kidsStation
            }
            return .parentControl
        }
    }

    func openGamesHub() {
        gamesTabRequested = true
        interfaceOverride = .kids
        currentChildProfile = nil
    }

    /// Unlocks Kids Station with the family PIN (local cache or cloud callable).
    func unlockKidsStation(pin: String) async -> Bool {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }

        // 1) Local family already on this device
        if let family = store.family, family.settings.kidsStationPIN == trimmed {
            kidsSessionUnlocked = true
            interfaceOverride = .kids
            currentChildProfile = nil
            return true
        }

        // 2) Cloud lookup (works without parent password when functions are deployed)
        guard isCloudEnabled else { return false }
        do {
            let ok = try await cloudSync.openKidsSession(pin: trimmed)
            if ok {
                kidsSessionUnlocked = true
                interfaceOverride = .kids
                currentChildProfile = nil
                return true
            }
            return false
        } catch {
            print("[KidsPIN] unlock failed: \(error.localizedDescription)")
            return false
        }
    }

    func lockKidsSession() {
        kidsSessionUnlocked = false
        currentChildProfile = nil
        interfaceOverride = .automatic
    }

    /// Routes from a push notification tap (or local notification).
    func handleNotificationRoute(_ route: String?) {
        lastNotificationRoute = route
        guard let route, isAuthenticated || kidsSessionUnlocked else {
            pendingDeepLink = route
            return
        }
        applyDeepLink(route)
    }

    func applyDeepLink(_ route: String) {
        interfaceOverride = .parent
        currentChildProfile = nil
        // Future: switch parent tab via a published index.
        switch route {
        case "approvals", "today":
            toastInfo("Open Today to review approvals")
        case "rewards":
            toastInfo("Open Rewards to review requests")
        case "kids":
            interfaceOverride = .kids
        default:
            break
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
                    guard store.isAuthenticated else {
                        authenticationError = "Account created but your family did not load. Try signing in."
                        return
                    }
                    completion?()
                    await registerForPushWhenCloudEnabled()
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
                    // Only dismiss the sheet when a family is actually loaded.
                    guard store.isAuthenticated else {
                        authenticationError = "Sign-in did not finish loading your family. Please try again."
                        return
                    }
                    completion?()
                    await registerForPushWhenCloudEnabled()
                } catch {
                    print("[Auth] signIn UI error: \(error.localizedDescription)")
                    authenticationError = friendlyAuthError(error)
                }
            } else {
                do {
                    try store.signIn(email: email, password: password)
                    guard store.isAuthenticated else {
                        authenticationError = "Sign-in did not finish loading your family. Please try again."
                        return
                    }
                    completion?()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            }
        }
    }

    /// Join an existing family using a shared family code.
    /// Cloud path: co-parent creates their own Firebase account and attaches
    /// to the existing family. Local fallback only when Firebase is absent.
    func joinWithCode(
        code: String,
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
                    try await cloudSync.joinFamilyWithCode(
                        code: code,
                        email: email,
                        password: password
                    )
                    completion?()
                    await registerForPushWhenCloudEnabled()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            } else {
                do {
                    try store.joinFamily(withCode: code, email: email, password: password)
                    completion?()
                } catch {
                    authenticationError = friendlyAuthError(error)
                }
            }
        }
    }

    func signOut() {
        currentChildProfile = nil
        interfaceOverride = .automatic
        familyBootstrapPIN = nil
        authenticationError = nil
        successMessage = nil
        isLoading = false
        cloudSync.signOut()
        #if canImport(FirebaseFunctions) && canImport(FirebaseMessaging) && canImport(FirebaseCore)
        Task { @MainActor in
            await NotificationService.shared.unregisterToken()
        }
        #endif
    }

    /// Clears auth-sheet messages so a failed Sign in does not reappear when
    /// the user opens Create family or Join.
    func clearAuthMessages() {
        authenticationError = nil
        successMessage = nil
    }

    /// After a successful cloud sign-in/sign-up, request notification
    /// permission and upload this device's FCM token. Runs on the main actor
    /// so NotificationService (which is @MainActor) can be touched safely.
    private func registerForPushWhenCloudEnabled() async {
        #if canImport(UserNotifications)
        let granted = await NotificationService.shared.requestAuthorizationIfNeeded()
        if granted {
            await NotificationService.shared.uploadTokenIfNeeded()
        }
        #endif
    }

    /// Sends a password reset email via Firebase.
    func sendPasswordReset(email: String) {
        authenticationError = nil
        successMessage = nil
        Task { @MainActor in
            do {
                try await cloudSync.sendPasswordReset(email: email)
                successMessage = "Password reset email sent. Check your inbox."
            } catch {
                authenticationError = friendlyAuthError(error)
            }
        }
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
        if message.contains("network") || message.contains("offline") || message.contains("internet")
            || message.contains("unavailable") || message.contains("connectivity") {
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

    /// Toast helpers so feature code stays short.
    func toastSuccess(_ message: String) {
        ToastCenter.shared.success(message)
    }

    func toastError(_ message: String) {
        ToastCenter.shared.error(message)
    }

    func toastInfo(_ message: String) {
        ToastCenter.shared.info(message)
    }

    func toastSuccessUndo(_ message: String, action: @escaping () -> Void) {
        ToastCenter.shared.successUndo(message, action: action)
    }
}

enum ApplicationMode {
    case login
    case parentControl
    case kidsSelection
    case kidsStation
}
