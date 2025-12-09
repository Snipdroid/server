import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class IconPack: Model, @unchecked Sendable {
    static let schema = "icon_packs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "designer_id")
    var designer: Designer

    @Children(for: \.$iconPack)
    var versions: [IconPackVersion]

    @Field(key: "name")
    var name: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, designerId: Designer.IDValue, name: String) {
        self.id = id
        self.$designer.id = designerId
        self.name = name
    }
}
