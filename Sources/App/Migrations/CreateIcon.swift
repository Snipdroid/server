import Fluent

struct CreateIcon: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("icon")
            .id()
            .field("package_name", .string, .required)
            .field("image", .data, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("icon").delete()
    }
}
