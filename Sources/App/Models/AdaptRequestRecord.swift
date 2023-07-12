//
//  AdaptRequestRecord.swift
//  
//
//  Created by Butanediol on 2022/12/31.
//

import Fluent
import Vapor

final class AdaptRequestRecord: Model, Content {
    static let schema = "adapt_request_records"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created_at", on: .create)
    var created: Date?

    @Field(key: "version")
    var version: Int

    @Parent(key: "icon_pack")
    var fromIconPack: IconPack

    @Parent(key: "app_info")
    var appInfo: AppInfo

    @Parent(key: "adapt_request")
    var belongsTo: AdaptRequest

    init() { }

    init(version: Int, from iconPackId: IconPack.IDValue, for appInfoId: AppInfo.IDValue, belongsTo: AdaptRequest.IDValue) {
        self.id = id
        self.version = version
        self.$fromIconPack.id = iconPackId
        self.$appInfo.id = appInfoId
        self.$belongsTo.id = belongsTo
    }

    convenience init(_ request: AdaptRequest) throws {
        self.init(
            version: request.version, 
            from: request.$fromIconPack.id, 
            for: request.$appInfo.id, 
            belongsTo: try request.requireID()
        )
    }
}