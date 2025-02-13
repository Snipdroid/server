import Fluent
import Vapor

import struct Foundation.Date
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Designer: Model, @unchecked Sendable {
    static let schema = "designers"

    @ID(key: .id)
    var id: UUID?

    @Children(for: \.$designer)
    var iconPackVersions: [IconPackVersion]

    @Field(key: "name")
    var name: String

    @Field(key: "email")
    var email: String

    @Field(key: "passwordHash")
    var passwordHash: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
}

struct CreateDesigner: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Designer.schema)
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("passwordHash", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Designer.schema).delete()
    }
}