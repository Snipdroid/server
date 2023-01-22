//
//  11-AddTimestampToAppInfo.swift
//  
//
//  Created by Butanediol on 2023/1/20.
//

import Vapor
import Fluent

struct AddTimestampToAppInfo: AsyncMigration {
    func prepare(on database: Database) async throws {
        let dateString = ISO8601DateFormatter().string(from: Date())
        try await database.schema("app_infos")
            .field("created_at", .datetime, .required, .sql(.default(dateString)))
            .field("updated_at", .datetime)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("app_infos")
            .deleteField("created_at")
            .deleteField("updated_at")
            .update()
    }
}
