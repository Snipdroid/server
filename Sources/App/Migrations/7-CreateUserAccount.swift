//
//  CreateUserAccount.swift
//  
//
//  Created by Butanediol on 2023/1/5.
//

import Fluent

struct CreateUserAccount: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_accounts")
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime)
            .field("last_changed_at", .datetime)
            .field("deleted_at", .datetime)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user_accounts").delete()
    }
}
