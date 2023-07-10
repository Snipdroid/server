//
//  File.swift
//  
//
//  Created by Butanediol on 2022/12/31.
//

import Fluent
import Vapor

final class IconRequest: Model, Content {
    static let schema = "icon_requests"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "count")
    var count: Int

    @Field(key: "version")
    var version: String?

    @Parent(key: "icon_pack")
    var fromIconPack: IconPack

    @Parent(key: "app_info")
    var appInfo: AppInfo

    init() { }

    init(id: UUID? = nil, version: String? = nil, count: Int = 1, from iconPackId: IconPack.IDValue, for appInfoId: AppInfo.IDValue) {
        self.id = id
        self.count = count
        self.version = version
        self.$fromIconPack.id = iconPackId
        self.$appInfo.id = appInfoId
    }
}

extension IconRequest {
    struct Create: Codable {
        let version: String?
        let appInfo: AppInfo.IDValue
    }

    struct Created: Codable {
        let id: UUID?
        let version: String?
        let count: Int
        let appInfo: AppInfo.Create
    }
}
