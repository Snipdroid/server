import Vapor

extension AppInfo {
    struct Query: Content {
        let byName: String?
        let byPackageName: String?
        let byMainActivity: String?
    }
}