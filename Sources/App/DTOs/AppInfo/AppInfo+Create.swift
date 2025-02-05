import Vapor 

extension AppInfo {
    struct Create: Content {
        let defaultName: String
        let localizedName: String
        let languageCode: String
        let packageName: String
        let mainActivity: String
    }

    convenience init(create: Create) {
        self.init(id: UUID(), defaultName: create.defaultName, packageName: create.packageName, mainActivity: create.mainActivity)
    }
}