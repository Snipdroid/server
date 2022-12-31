//
//  File.swift
//  
//
//  Created by Butanediol on 2022/12/31.
//

import Fluent
import Vapor

struct IconRequestDTO: Codable {
    let appInfoId: UUID?
    let iconRequestId: UUID?
    let appName: String
    let packageName: String
    let activityName: String
    let count: Int
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
