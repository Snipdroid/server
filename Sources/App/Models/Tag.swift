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

    /// RGBA color
    @Field(key: "color")
    var color: UInt32
    
    init(id: UUID? = nil, name: String, appInfos: [AppInfo], color: UInt32 = .random(in: UInt32.min...UInt32.max)) {
        self.id = id
        self.name = name
        self.appInfos = appInfos
        self.color = color
    }
    
    init() {}
}