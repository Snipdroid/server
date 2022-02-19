import Fluent

struct CreateAppInfo: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("app_infos")
            .id()
            .field("app_name", .string, .required)
            .field("package_name", .string, .required)
            .field("activity_name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("app_infos").delete()
    }
}
