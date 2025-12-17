import Fluent
import FluentDTOMacro
import Vapor

import struct Foundation.Date
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
@FluentDTO
final class Designer: Model, Authenticatable, @unchecked Sendable {
    static let schema = "designers"

    @ID(key: .id)
    var id: UUID?

    @Children(for: \.$designer)
    var iconPacks: [IconPack]

    @Field(key: "oidc_subject")
    var oidcSubject: String

    @Field(key: "oidc_issuer")
    var oidcIssuer: String

    @OptionalField(key: "email")
    var email: String?

    @OptionalField(key: "name")
    var name: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "role")
    var role: DesignerRole

    init() {}

    init(
        id: UUID? = nil, oidcSubject: String, oidcIssuer: String, email: String? = nil,
        name: String? = nil
    ) {
        self.id = id
        self.oidcSubject = oidcSubject
        self.oidcIssuer = oidcIssuer
        self.email = email
        self.name = name
    }
}

extension DesignerDTO: Content {}

struct CreateDesigner: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Designer.schema)
            .id()
            .field("oidc_subject", .string, .required)
            .field("oidc_issuer", .string, .required)
            .field("email", .string)
            .field("name", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("role", .int, .required, .sql(.default(DesignerRole.regular.rawValue)))
            .unique(on: "oidc_subject", "oidc_issuer")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Designer.schema).delete()
    }
}

enum DesignerRole: Int, Codable {
    case regular = 0
    case admin, curator
}
