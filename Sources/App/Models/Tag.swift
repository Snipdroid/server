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
    var color: Int64
    
    init(id: UUID? = nil, name: String, color: UInt32? = nil) {
        self.id = id
        self.name = name
        self.color = Int64(color ?? .random(in: UInt32.min...UInt32.max))
    }

    convenience init(_ create: Create) {
        self.init(name: create.name, color: create.color)
    }
    
    init() {}
}

extension Tag {
    struct Create: Codable {
        let name: String
        let color: UInt32?
    }
}