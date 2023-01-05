//
//  CreateUserToken.swift
//  
//
//  Created by Butanediol on 2023/1/5.
//

import Fluent

struct CreateUserToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_tokens")
            .id()
            .field("value", .string, .required)
            .field("user_id", .uuid, .required, .references("user_accounts", "id"))
            .field("expire_at", .date)
            .unique(on: "value")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user_tokens").delete()
    }
}
