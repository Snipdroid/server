import Fluent

struct CreateIconPack: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(IconPack.schema)
            .id()
            .field("designer_id", .uuid, .required, .references(Designer.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "designer_id", "name")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(IconPack.schema).delete()
    }
}
