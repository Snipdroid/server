import Fluent
import Vapor

struct AppInfoDTO: Codable {
    let appName: String
    let packageName: String
    let activityName: String
    
    let iconPack: String?
    
    init(appName: String, packageName: String, activityName: String, iconPack: String?) {
        self.appName = appName
        self.packageName = packageName
        self.activityName = activityName
        self.iconPack = iconPack
    }
    
    init(_ appInfo: AppInfo) {
        self.appName = appInfo.appName
        self.packageName = appInfo.packageName
        self.activityName = appInfo.activityName
        self.iconPack = nil
    }
}

final class AppInfo: Model, Content {
    static let schema = "app_infos"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "app_name")
    var appName: String

    @Field(key: "package_name")
    var packageName: String

    @Field(key: "activity_name")
    var activityName: String
    
    @Siblings(through: AppInfoTagPivot.self, from: \.$appInfo, to: \.$tag)
    var tags: [Tag]

    init() { }

    init(id: UUID? = nil, appName: String, packageName: String, activityName: String) {
        self.id = id
        self.appName = appName
        self.packageName = packageName
        self.activityName = activityName
    }

    init(_ dto: AppInfoDTO) {
        self.id = UUID()
        self.appName = dto.appName
        self.packageName = dto.packageName
        self.activityName = dto.activityName
    }

    static func getExample() -> AppInfo {
        AppInfo(
            id: UUID(), 
            appName: "Example App", 
            packageName: "com.example\(Int.random()).app", 
            activityName: "example\(Int.random()).activity"
        )
    }

    func regexSearch(_ key: KeyPath<AppInfo, String>, with pattern: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let stringRange = NSRange(location: 0, length: self[keyPath: key].utf16.count)
        return regex.firstMatch(in: self[keyPath: key], range: stringRange) != nil
    }
}

extension AppInfo: Equatable {
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.packageName == rhs.packageName && lhs.activityName == rhs.activityName
    }
}
