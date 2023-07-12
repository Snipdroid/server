//
//  AdaptRequest.swift
//  
//
//  Created by Butanediol on 2022/12/31.
//

import Fluent
import Vapor

final class AdaptRequest: Model, Content {
    static let schema = "adapt_requests"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "count")
    var count: Int

    @Field(key: "version")
    var version: Int

    @Parent(key: "icon_pack")
    var fromIconPack: IconPack

    @Parent(key: "app_info")
    var appInfo: AppInfo

    @Children(for: \.$belongsTo)
    var records: [AdaptRequestRecord]

    init() { }

    init(id: UUID? = nil, version: Int, count: Int = 1, from iconPackId: IconPack.IDValue, for appInfoId: AppInfo.IDValue) {
        self.id = id
        self.count = count
        self.version = version
        self.$fromIconPack.id = iconPackId
        self.$appInfo.id = appInfoId
    }
}

extension AdaptRequest {
    struct Create: Codable {
        let version: Int
        let appInfo: AppInfo.IDValue
    }

    struct Created: Codable {
        let id: UUID?
        let version: Int
        let count: Int
        let appInfo: AppInfo.Create
    }
}
