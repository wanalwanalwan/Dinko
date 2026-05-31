import Foundation

enum SupabaseConfig {
    static let url: String = {
        if let value = Bundle.main.infoDictionary?["SupabaseURL"] as? String, !value.isEmpty {
            return value
        }
        return "https://dtsmezwkxytpidtjgcid.supabase.co"
    }()

    static let anonKey: String = {
        if let value = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String, !value.isEmpty {
            return value
        }
        return "sb_publishable_OMtj-652wf8e5kmdsEQirQ_FPKZR4gA"
    }()

    static let agentFunctionURL = "\(url)/functions/v1/dinkit-agent"

    static let realtimeURL: String = {
        // Convert https://xxx.supabase.co to wss://xxx.supabase.co/realtime/v1/websocket
        let wsBase = url.replacingOccurrences(of: "https://", with: "wss://")
        return "\(wsBase)/realtime/v1/websocket"
    }()
}
