//
//  CreateAppInfoTag.swift
//  
//
//  Created by Butanediol on 2023/1/1.
//

import Fluent

struct CreateAppInfoTagPivot: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("app_info_tag_pivots")
            .id()
            .field("app_info_id", .uuid, .required, .references("app_infos", "id"))
            .field("tag_id", .uuid, .required, .references("tags", "id"))
            .unique(on: "tag_id", "app_info_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("app_info_tag_pivots").delete()
    }
}
