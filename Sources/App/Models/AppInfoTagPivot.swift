//
//  AppInfoTagPivot.swift
//  
//
//  Created by Butanediol on 2023/1/1.
//

import Fluent
import Vapor

struct TaggingRequest: Codable {
    let tagId: UUID?
    let tagName: String?
    let appInfoId: UUID
    
    enum TagBy {
        case id(UUID)
        case name(String)
    }
    
    var by: TagBy? {
        if let tagId {
            return .id(tagId)
        } else if let tagName {
            return .name(tagName)
        } else {
            return nil
        }
    }
}

final class AppInfoTagPivot: Model, Content {
    static let schema = "app_info_tag_pivots"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "app_info_id")
    var appInfo: AppInfo

    @Parent(key: "tag_id")
    var tag: Tag

    init() { }

    init(id: UUID? = nil, appInfo: AppInfo, tag: Tag) throws {
        self.id = id
        self.$appInfo.id = try appInfo.requireID()
        self.$tag.id = try tag.requireID()
    }
}
