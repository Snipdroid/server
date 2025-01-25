import Fluent
import Vapor
import struct Foundation.UUID
import struct Foundation.Date

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class AppInfo: Model, @unchecked Sendable {
    static let schema = "app_infos"
    
    @ID(key: .id)
    var id: UUID?

    @Children(for: \.$appInfo)
    var localizedNames: [AppLocalizedName]

    @Field(key: "package_name")
    var packageName: String

    @Field(key: "main_activity")
    var mainActivity: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Field(key: "count")
    var count: Int

    init() { }

    init(id: UUID? = nil, packageName: String, mainActivity: String, count: Int = 0) {
        self.id = id
        self.packageName = packageName
        self.mainActivity = mainActivity
        self.count = count
    }
}

struct CreateAppInfo: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(AppInfo.schema)
            .id()
            .field("package_name", .string, .required)
            .field("main_activity", .string, .required)
            .field("created_at", .datetime)
            .field("count", .int, .required, .custom("DEFAULT 0"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(AppInfo.schema).delete()
    }
}

extension AppInfo: Content {}