//
//  AddSuggestedName.swift
//  
//
//  Created by Butanediol on 2023/1/14.
//

import Vapor
import Fluent

struct AddSuggestedName: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("app_infos")
            .field("suggested_name", .string)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("app_infos")
            .deleteField("suggested_name")
            .update()
    }
}
