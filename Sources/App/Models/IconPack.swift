import Fluent
import Vapor

final class IconPack: Model, Content {
    static let schema = "icon_packs"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Children(for: \.$fromIconPack)
    var requests: [IconRequest]

    @OptionalParent(key: "designer")
    var designer: UserAccount?
    
    init() { }

    init(
        id: UUID? = nil,
        name: String,
        designer: UserAccount.IDValue? = nil
    ) {
        self.id = id
        self.name = name
        self.requests = []
        self.$designer.id = designer
    }
}

struct AddDesignerToIconPack: AsyncMigration {
    func prepare(on database: FluentKit.Database) async throws {
        try await database.schema("icon_packs")
            .field("designer", .uuid, .references("user_accounts", "id"))
            .update()
    }
    
    func revert(on database: FluentKit.Database) async throws {
        try await database.schema("icon_packs")
            .deleteField("designer")
            .update()
    }
}
