import Fluent
import Vapor

final class IconPackCollaborators: Model, @unchecked Sendable {
    static let schema = "icon_pack+collaborators"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "icon_pack_id")
    var iconPack: IconPack

    @Parent(key: "collaborator_id")
    var collaborator: Designer

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalParent(key: "invited_by")
    var invitedBy: Designer?

    init() {}

    init(
        id: UUID? = nil, iconPackId: IconPack.IDValue, collaboratorId: Designer.IDValue,
        invitedBy: Designer
    ) {
        self.id = id
        self.$iconPack.id = iconPackId
        self.$collaborator.id = collaboratorId
        self.invitedBy = invitedBy
    }
}

struct CreateIconPackCollaborator: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(IconPackCollaborators.schema)
            .id()
            .field(
                IconPackCollaborators.fieldKey(for: \.$iconPack), .uuid, .required,
                .references(IconPack.schema, IconPack.fieldKey(for: \.$id), onDelete: .cascade)
            )
            .field(
                IconPackCollaborators.fieldKey(for: \.$collaborator), .uuid, .required,
                .references(Designer.schema, Designer.fieldKey(for: \.$id), onDelete: .cascade)
            )
            .field(IconPackCollaborators.fieldKey(for: \.$createdAt), .datetime)
            .field(
                IconPackCollaborators.fieldKey(for: \.$invitedBy), .uuid,
                .references(Designer.schema, Designer.fieldKey(for: \.$id), onDelete: .setNull)
            )
            .unique(
                on: IconPackCollaborators.fieldKey(for: \.$collaborator),
                IconPackCollaborators.fieldKey(for: \.$iconPack)
            )
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(IconPackCollaborators.schema).delete()
    }
}
