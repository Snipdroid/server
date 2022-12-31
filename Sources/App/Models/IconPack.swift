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

final class IconRequest: Model, Content {
    static let schema = "icon_requests"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "count")
    var count: Int

    @Parent(key: "icon_pack")
    var fromIconPack: IconPack

    @Parent(key: "app_info")
    var appInfo: AppInfo

    init() { }

    init(id: UUID? = nil, count: Int = 1, from iconPackId: IconPack.IDValue, for appInfoId: AppInfo.IDValue) {
        self.id = id
        self.count = count
        self.$fromIconPack.id = iconPackId
        self.$appInfo.id = appInfoId
    }
}