import Vapor 

extension AppInfo {
    struct Create: Content {
        let localizedName: String
        let languageCode: String
        let packageName: String
        let mainActivity: String
    }

    convenience init(create: Create) throws {
        self.init(id: UUID(), packageName: create.packageName, mainActivity: create.mainActivity)
    }
}