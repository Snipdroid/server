//
//  File.swift
//  
//
//  Created by Butanediol on 2023/1/1.
//

import Fluent

struct CreateTag: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("tags")
            .id()
            .field("name", .string, .required)
            .field("color", .uint32, .required)
            .unique(on: "name")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("tags").delete()
    }
}
