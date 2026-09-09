import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// Schedules local banners for family events detected from cloud sync.
///
/// Free-tier fallback until APNs / paid Developer Program remote pushes are
/// available: works whenever the app is alive (foreground → suppressed by the
/// delegate since the UI already shows it; background → banner + sound).
/// Respects `FamilySettings.enableNotifications` (the existing toggle).
enum LocalFamilyNotifier {

    /// Fires one local notification per event. No-op when notifications are
    /// disabled in family settings or the permission was not granted.
    static func notify(_ events: [FamilyChangeEvent], enabled: Bool) {
        guard enabled, !events.isEmpty else { return }
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
            guard granted else { return }
            for event in events {
                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = event.body
                content.sound = .default
                let id = "kiddo-\(event.kind.rawValue)-\(UUID().uuidString)"
                let request = UNNotificationRequest(
                    identifier: id, content: content, trigger: nil
                )
                center.add(request)
            }
        }
        #endif
    }
}
