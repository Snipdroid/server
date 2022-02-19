import Fluent
import Vapor

final class AppInfo: Model, Content {
    static let schema = "app_infos"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "package_name")
    var packageName: String

    @Field(key: "activity_name")
    var activityName: String

    init() { }

    init(id: UUID? = nil, packageName: String, activityName: String) {
        self.id = id
        self.packageName = packageName
        self.activityName = activityName
    }
}
