import Foundation

enum DUPRConfig {
    static let clientKey: String = {
        if let v = Bundle.main.infoDictionary?["DUPRClientKey"] as? String, !v.isEmpty { return v }
        return "test-ck-a4261aaf-c79f-400f-fdaf-6d0b31197037"
    }()

    static let clientID: String = {
        if let v = Bundle.main.infoDictionary?["DUPRClientID"] as? String, !v.isEmpty { return v }
        return "7998359216"
    }()

    // UAT environment — swap for prod URLs before App Store release
    static let ssoBaseURL = "https://uat.dupr.gg"
    static let apiBaseURL = "https://api.uat.dupr.gg"
    static let partnerBaseURL = "https://uat.mydupr.com"

    static var encodedClientKey: String {
        Data(clientKey.utf8).base64EncodedString()
    }

    static var ssoURL: URL {
        URL(string: "\(ssoBaseURL)/login-external-app/\(encodedClientKey)")!
    }
}
