import Fluent

struct CreateIconPack: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("icon_packs")
            .id()
            .field("name", .string, .required)
            .unique(on: "name")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("icon_packs").delete()
    }
}
