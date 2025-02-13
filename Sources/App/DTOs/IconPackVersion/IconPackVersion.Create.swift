import Vapor 

extension IconPackVersion {
    struct Create: Content {
        let expireAt: Date
        let versionString: String
    }
}