import Foundation

enum SupabaseConfig {
    static let url: String = {
        guard let value = Bundle.main.infoDictionary?["SupabaseURL"] as? String, !value.isEmpty else {
            assertionFailure("Missing SupabaseURL in Info.plist. Create Dinko/Configuration/Secrets.xcconfig from the .example file.")
            return ""
        }
        return value
    }()

    static let anonKey: String = {
        guard let value = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String, !value.isEmpty else {
            assertionFailure("Missing SupabaseAnonKey in Info.plist. Create Dinko/Configuration/Secrets.xcconfig from the .example file.")
            return ""
        }
        return value
    }()

    static let agentFunctionURL = "\(url)/functions/v1/dinkit-agent"
}
