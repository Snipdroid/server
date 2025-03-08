import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class AppLocalizedName: Model, @unchecked Sendable {
    static let schema = "app_localized_names"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "app_info_id")
    var appInfo: AppInfo

    @Field(key: "language_code")
    var languageCode: String

    @Field(key: "name")
    var name: String

    @Field(key: "is_primary")
    var isPrimary: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, appInfoId: UUID, languageCode: String, name: String, isPrimary: Bool) {
        self.id = id
        self.$appInfo.id = appInfoId
        self.languageCode = languageCode
        self.name = name
        self.isPrimary = isPrimary
    }
}

struct CreateAppLocalizedName: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(AppLocalizedName.schema)
            .id()
            .field("app_info_id", .uuid, .references(AppInfo.schema, "id"))
            .field("language_code", .string, .required)
            .field("name", .string, .required)
            .field("is_primary", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(AppLocalizedName.schema).delete()
    }
}