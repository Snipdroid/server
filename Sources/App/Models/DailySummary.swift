import Fluent

import struct Foundation.Date
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class DailySummary: Model, @unchecked Sendable {
    static let schema = "daily_summaries"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "count")
    var count: Int

    @Parent(key: "designer_id")
    var designer: Designer

    @Timestamp(key: "date", on: .none)
    var date: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, count: Int, designerId: UUID, date: Date) {
        self.id = id
        self.count = count
        self.$designer.id = designerId
        self.date = date
    }
}

struct CreateDailySummary: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(DailySummary.schema)
            .id()
            .field(
                "designer_id", .uuid, .required, .references("designers", "id", onDelete: .cascade)
            )
            .field("count", .int, .required)
            .field("date", .date, .required)
            .field("created_at", .date, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(DailySummary.schema).delete()
    }
}
