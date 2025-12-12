import Fluent
import FluentDTOMacro
import Vapor

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
@FluentDTO
final class IconPackVersion: Model, @unchecked Sendable {
    static let schema = "icon_pack_versions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "icon_pack_id")
    var iconPack: IconPack

    @Children(for: \.$iconPackVersion)
    var requestRecords: [RequestRecord]

    @Field(key: "version_string")
    var versionString: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, iconPackId: IconPack.IDValue, versionString: String) {
        self.id = id
        self.$iconPack.id = iconPackId
        self.versionString = versionString
    }
}

extension IconPackVersionDTO: Content {}

struct CreateIconPackVersion: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(IconPackVersion.schema)
            .id()
            .field(
                "icon_pack_id", .uuid, .required,
                .references(IconPack.schema, "id", onDelete: .cascade)
            )
            .field("version_string", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "icon_pack_id", "version_string")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(IconPackVersion.schema).delete()
    }
}
