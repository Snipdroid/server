//
//  Tag.swift
//  
//
//  Created by Butanediol on 2023/1/1.
//

import Vapor
import Fluent

final class Tag: Model, Content {
    static let schema = "tags"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Siblings(through: AppInfoTagPivot.self, from: \.$tag, to: \.$appInfo)
    var appInfos: [AppInfo]
    
    init(id: UUID? = nil, name: String, appInfos: [AppInfo]) {
        self.id = id
        self.name = name
        self.appInfos = appInfos
    }
    
    init() {}
}
