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

    init() { }

    init(id: UUID? = nil, appName: String, packageName: String, activityName: String) {
        self.id = id
        self.appName = appName
        self.packageName = packageName
        self.activityName = activityName
    }

    static func getExample() -> AppInfo {
        AppInfo(id: UUID(), appName: "Example App", packageName: "com.example\(Int.random()).app", activityName: "example\(Int.random()).activity")
    }
}
