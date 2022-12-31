import Fluent

struct CreateAppInfo: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("app_infos")
            .id()
            .field("app_name", .string, .required)
            .field("package_name", .string, .required)
            .field("activity_name", .string, .required)
            .field("signature", .string)
            .field("count", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("app_infos").delete()
    }
}