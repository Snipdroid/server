import Vapor

extension IconPackVersion {
    struct TokenRequest: Content {
        let expireAt: Date
    }

    struct TokenResponse: Content {
        let token: String
    }
}
