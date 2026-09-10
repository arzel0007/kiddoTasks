import UIKit

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Bridges APNs ↔ Firebase Messaging. The Firebase SDK needs the APNs device
/// token so FCM can address this device; the FCM token itself is uploaded to
/// the cloud by `NotificationService` once this happens.
///
/// This type is deliberately tiny — all app-facing logic lives in
/// `NotificationService`, which is reachable from `AppState`.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(FirebaseMessaging)
        // Defaults to YES when the app is built with FCM; keep it explicit.
        Messaging.messaging().isAutoInitEnabled = true
        NotificationService.shared.reconfigureAppDidFinishLaunching()
        #endif
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Not fatal: the simulator and devices without APNs fallback to FCM
        // registration only. Log for diagnostics.
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let route = (userInfo["route"] as? String) ?? "today"
        NotificationService.shared.handleRemoteNotification(route: route)
        completionHandler(.newData)
    }
}