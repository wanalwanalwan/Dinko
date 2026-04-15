import Foundation

enum SupabaseConfig {
    static let url: String = {
        guard let value = Bundle.main.infoDictionary?["SupabaseURL"] as? String, !value.isEmpty else {
            // Fallback for previews / tests where Info.plist keys aren't injected
            return "https://dtsmezwkxytpidtjgcid.supabase.co"
        }
        return value
    }()

    static let anonKey: String = {
        guard let value = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String, !value.isEmpty else {
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR0c21lendreHl0cGlkdGpnY2lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNDY4OTMsImV4cCI6MjA4NzgyMjg5M30.AGUvf40_cXo7gZOTgCEWZU9R-domGoogL9EXB0HBHew"
        }
        return value
    }()

    static let agentFunctionURL = "\(url)/functions/v1/dinkit-agent"
}
