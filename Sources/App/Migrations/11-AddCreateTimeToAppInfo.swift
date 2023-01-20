//
//  11-AddCreateTimeToAppInfo.swift
//  
//
//  Created by Butanediol on 2023/1/20.
//

import Vapor
import Fluent

struct AddCreateTimeToAppInfo: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("app_infos")
            .field("createdAt", .datetime, .required, .sql(.default(Date().ISO8601Format())))
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("app_infos")
            .deleteField("createdAt")
            .update()
    }
}
