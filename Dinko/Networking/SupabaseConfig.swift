import Foundation

enum SupabaseConfig {
    static let url: String = {
        guard let value = Bundle.main.infoDictionary?["SupabaseURL"] as? String, !value.isEmpty else {
            assertionFailure("SupabaseURL missing from Info.plist — add it to Secrets.xcconfig")
            return ""
        }
        return value
    }()

    static let anonKey: String = {
        guard let value = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String, !value.isEmpty else {
            assertionFailure("SupabaseAnonKey missing from Info.plist — add it to Secrets.xcconfig")
            return ""
        }
        return value
    }()

    static let agentFunctionURL = "\(url)/functions/v1/dinkit-agent"

    static let realtimeURL: String = {
        // Convert https://xxx.supabase.co to wss://xxx.supabase.co/realtime/v1/websocket
        let wsBase = url.replacingOccurrences(of: "https://", with: "wss://")
        return "\(wsBase)/realtime/v1/websocket"
    }()
}
