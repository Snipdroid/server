import Fluent
import Vapor

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

    @Field(key: "signature")
    var signature: String

    @Field(key: "count")
    var count: Int?

    init() { }

    init(id: UUID? = nil, appName: String, packageName: String, activityName: String, signature: String = "", count: Int = 1) {
        self.id = id
        self.appName = appName
        self.packageName = packageName
        self.activityName = activityName
        self.signature = signature
        self.count = count
    }

    static func getExample() -> AppInfo {
        AppInfo(
            id: UUID(), 
            appName: "Example App", 
            packageName: "com.example\(Int.random()).app", 
            activityName: "example\(Int.random()).activity"
        )
    }

    func eraseSignature() -> AppInfo {
        .init(id: UUID(), appName: self.appName, packageName: self.packageName, activityName: self.activityName, signature: "", count: 1)
    }

    func regexSearch(_ key: KeyPath<AppInfo, String>, with pattern: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let stringRange = NSRange(location: 0, length: self[keyPath: key].utf16.count)
        return regex.firstMatch(in: self[keyPath: key], range: stringRange) != nil
    }
}
