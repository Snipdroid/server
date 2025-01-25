import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class RequestRecord: Model, @unchecked Sendable {
    static let schema = "request_records"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "app_info_id")
    var appInfo: AppInfo

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalParent(key: "app_version_id")
    var appVersion: AppVersion?

    init() { }

    init(id: UUID? = nil, appInfoId: UUID, appVersionId: UUID?) {
        self.id = id
        self.$appInfo.id = appInfoId
        self.$appVersion.id = appVersionId
    }
}

struct CreateRequestRecord: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(RequestRecord.schema)
            .id()
            .field("app_info_id", .uuid, .required, .references(AppInfo.schema, "id"))
            .field("app_version_id", .uuid, .references(AppVersion.schema, "id"))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(RequestRecord.schema).delete()
    }
}