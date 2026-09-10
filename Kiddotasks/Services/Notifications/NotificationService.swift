import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Owns notification permission, the FCM token, and the server-side token
/// registry for push delivery.
///
/// The actual *copy* for each event lives in the backend triggers
/// (`Firebase/functions/src/notifications.ts`); this service is only
/// responsible for making sure a device token is registered so those pushes
/// can arrive.
@MainActor
final class NotificationService: NSObject {

    static let shared = NotificationService()

    private(set) var isPermissionGranted = false
    private(set) var fcmToken: String?

    private override init() {
        super.init()
        #if canImport(FirebaseMessaging)
        if FirebaseApp.app() != nil {
            Messaging.messaging().delegate = self
        }
        #endif
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().delegate = self
        #endif
    }

    /// Called from the AppDelegate once launch finishes so the service can
    /// observe the current FCM token (the delegate may already have fired, or
    /// may fire again on refresh).
    ///
    /// Firebase 12: `Messaging.messaging().fcmToken` is deprecated in favor of
    /// `register(completion:)`, which asynchronously returns the current token.
    /// We surface it through the delegate path (didReceiveRegistrationToken),
    /// so this just kicks off a refresh when the SDK is configured.
    func reconfigureAppDidFinishLaunching() {
        #if canImport(FirebaseMessaging) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().register { error in
            if let error {
                // FCM token unavailable (e.g. no APNs on simulator yet); the
                // delegate path will try again when one arrives.
                print("FCM token fetch failed: \(error.localizedDescription)")
                return
            }
            // On success the SDK calls `didReceiveRegistrationToken`, which
            // uploads the token via `MessagingDelegate` below.
        }
        #endif
    }

    /// Asks the user for notification permission (first launch only) and, if
    /// granted, registers with APNs (which leads to the FCM token callback).
    func requestAuthorizationIfNeeded() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isPermissionGranted = true
        case .notDetermined:
            isPermissionGranted = (try? await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
        case .denied:
            isPermissionGranted = false
        @unknown default:
            isPermissionGranted = false
        }
        if isPermissionGranted {
            #if canImport(UIKit)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
        }
        return isPermissionGranted
        #else
        return false
        #endif
    }

    /// Uploads the current FCM token to the server-managed registry. Safe to
    /// call anytime — the backend upserts and ignores stale registrations.
    func uploadTokenIfNeeded() async {
        #if canImport(FirebaseMessaging) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil, let token = fcmToken else { return }
        do {
            _ = try await Functions.functions()
                .httpsCallable("registerDeviceToken")
                .call(["fcmToken": token, "platform": "ios"])
        } catch {
            // Non-fatal: the app still works; next launch retries.
        }
        #endif
    }

    /// Removes the device token from the cloud registry on sign-out.
    func unregisterToken() async {
        #if canImport(FirebaseMessaging) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil, let token = fcmToken else { return }
        do {
            _ = try await Functions.functions()
                .httpsCallable("unregisterDeviceToken")
                .call(["fcmToken": token])
        } catch {
            // Non-fatal: stale tokens are pruned by the backend on send failure.
        }
        #endif
    }

    /// Deep-link target stored for AppState to consume on the next UI pass.
    nonisolated func handleRemoteNotification(route: String?) {
        Task { @MainActor in
            AppState.sharedNotificationRoute = route ?? "today"
        }
    }
}

// MARK: - FCM token refresh

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let token = fcmToken
        Task { @MainActor in
            self.fcmToken = token
            await self.uploadTokenIfNeeded()
        }
    }
}

// MARK: - Foreground presentation + tap handling

extension NotificationService: UNUserNotificationCenterDelegate {

    /// While the app is in the foreground, we don't show banners: the in-app
    /// UI already reflects changes instantly via the live sync, and it avoids
    /// echoing an event the user just performed on this device. Banners appear
    /// whenever the app is backgrounded or terminated (system behavior).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let route = (userInfo["route"] as? String) ?? "today"
        handleRemoteNotification(route: route)
    }
}

extension AppState {
    /// Process-wide route set by NotificationService (bridged until we inject AppState).
    static var sharedNotificationRoute: String?
}