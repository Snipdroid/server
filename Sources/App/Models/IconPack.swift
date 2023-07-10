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

    @Parent(key: "designer")
    var designer: UserAccount
    
    @Field(key: "access_token")
    var accessToken: String
    
    init() { }

    init(
        id: UUID? = nil,
        name: String,
        designer: UserAccount.IDValue,
        accessToken: String
    ) {
        self.id = id
        self.name = name
        self.$designer.id = designer
        self.accessToken = accessToken
    }
}

extension IconPack {
    struct Create: Content {
        let name: String
    }
    
    struct Delete: Content {
        let id: UUID
    }
}

extension IconPack: Equatable {
    static func == (lhs: IconPack, rhs: IconPack) -> Bool {
        return lhs.id == rhs.id && lhs.id != nil
    }    
}

extension IconPack: ModelTokenAuthenticatable {
    static var userKey: KeyPath<IconPack, Parent<UserAccount>> {
        \IconPack.$designer
    }

    static var valueKey: KeyPath<IconPack, Field<String>> {
        \IconPack.$accessToken
    }

    var isValid: Bool {
        // No expiration
        true
    }
}