import Vapor 

extension AppVersion {
    struct Create: Content {
        let expireAt: Date
        let versionString: String
    }
}