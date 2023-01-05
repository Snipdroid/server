//
//  AddDesignerToIconPack.swift
//  
//
//  Created by Butanediol on 2023/1/5.
//

import Fluent

struct AddDesignerToIconPack: AsyncMigration {
    func prepare(on database: FluentKit.Database) async throws {
        try await database.schema("icon_packs")
            .field("designer", .uuid, .references("user_accounts", "id"))
            .field("access_token", .string)
            .unique(on: "access_token")
            .update()
    }
    
    func revert(on database: FluentKit.Database) async throws {
        try await database.schema("icon_packs")
            .deleteField("designer")
            .deleteField("access_token")
            .update()
    }
}
