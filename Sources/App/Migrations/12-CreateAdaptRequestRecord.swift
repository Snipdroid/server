import Fluent

struct CreateAdaptRequestRecord: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("adapt_request_records")
            .id()
            .field("created_at", .datetime, .required)
            .field("version", .int, .required)
            .field("icon_pack", .uuid, .required, .references("icon_packs", "id"))
            .field("app_info", .uuid, .required, .references("app_infos", "id"))
            .field("adapt_request", .uuid, .required, .references("adapt_requests", "id"))
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("adapt_request_records")
            .delete()
    }
}