import Fluent

struct CreateAdaptRequest: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("adapt_requests")
            .id()
            .field("count", .int, .required)
            .field("version", .int, .required)
            .field("icon_pack", .uuid, .required, .references("icon_packs", "id"))
            .field("app_info", .uuid, .required, .references("app_infos", "id"))
            .unique(on: "icon_pack", "app_info", "version")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("adapt_requests").delete()
    }
}