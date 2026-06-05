import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    private(set) var isAuthorized = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pkkl_notifications_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "pkkl_notifications_enabled")
            if newValue {
                scheduleDailyReminder()
            } else {
                cancelReminder()
            }
        }
    }

    var reminderHour: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "pkkl_reminder_hour")
            return val == 0 && !UserDefaults.standard.bool(forKey: "pkkl_reminder_hour_set") ? 18 : val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pkkl_reminder_hour")
            UserDefaults.standard.set(true, forKey: "pkkl_reminder_hour_set")
            if isEnabled { scheduleDailyReminder() }
        }
    }

    var reminderMinute: Int {
        get { UserDefaults.standard.integer(forKey: "pkkl_reminder_minute") }
        set {
            UserDefaults.standard.set(newValue, forKey: "pkkl_reminder_minute")
            if isEnabled { scheduleDailyReminder() }
        }
    }

    private static let categoryIdentifier = "SESSION_REMINDER"
    private static let requestIdentifier = "pkkl_daily_reminder"

    private init() {}

    func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                isAuthorized = granted
                if granted && isEnabled {
                    scheduleDailyReminder()
                }
            } catch {
                isAuthorized = false
            }
        }
    }

    func scheduleDailyReminder() {
        cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = "Time to log your session"
        content.body = "Just played? Log it in 30 seconds."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }
}
