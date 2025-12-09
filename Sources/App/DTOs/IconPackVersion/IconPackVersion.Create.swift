import Vapor

extension IconPackVersion {
    struct Create: Content {
        let versionString: String
    }
}