import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class AppVersion: Model, @unchecked Sendable {
    static let schema = "app_versions"
    
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "designer_id")
    var designer: Designer

    @Field(key: "version_string")
    var versionString: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, designerId: Designer.IDValue, versionString: String) {
        self.id = id
        self.$designer.id = designerId
        self.versionString = versionString
    }
}


struct CreateAppVersion: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(AppVersion.schema)
            .id()
            .field("designer_id", .uuid, .references(Designer.schema, "id"))
            .field("version_string", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(AppVersion.schema).delete()
    }
}