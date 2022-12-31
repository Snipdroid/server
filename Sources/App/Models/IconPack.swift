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

    init() { }

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
        self.requests = []
    }
}
