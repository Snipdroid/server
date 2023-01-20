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
    
    @Field(key: "count")
    var count: Int
    
    @Siblings(through: AppInfoTagPivot.self, from: \.$appInfo, to: \.$tag)
    var tags: [Tag]
    
    @Children(for: \.$appInfo)
    var requests: [IconRequest]
    
    @OptionalField(key: "suggestedName")
    var suggestedName: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, appName: String, packageName: String, activityName: String) {
        self.id = id
        self.appName = appName
        self.packageName = packageName
        self.activityName = activityName
        self.count = 0
    }

    init(_ create: AppInfo.Create) {
        self.id = UUID()
        self.appName = create.appName
        self.packageName = create.packageName
        self.activityName = create.activityName
        self.count = 0
    }
}

extension AppInfo: Equatable {
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.packageName == rhs.packageName && lhs.activityName == rhs.activityName
    }
}

extension AppInfo {
    struct Create: Content {
        let appName: String
        let packageName: String
        let activityName: String
        
        init(appName: String, packageName: String, activityName: String) {
            self.appName = appName
            self.packageName = packageName
            self.activityName = activityName
        }
        
        init(_ appInfo: AppInfo) {
            self.appName = appInfo.appName
            self.packageName = appInfo.packageName
            self.activityName = appInfo.activityName
        }
    }
    
    typealias Created = Create
}
