import Fluent
@preconcurrency import FluentPostgresDriver

struct AddPerformanceIndexes: AsyncMigration {
    func prepare(on database: Database) async throws {
        let db = database as! PostgresDatabase

        // Index for app_localized_names.app_info_id (used in JOIN and WHERE IN queries)
        _ = try await db.query("""
            CREATE INDEX idx_app_localized_names_app_info_id
            ON app_localized_names (app_info_id);
            """).get()

        // Index for request_records.app_info_id (used in JOIN queries)
        _ = try await db.query("""
            CREATE INDEX idx_request_records_app_info_id
            ON request_records (app_info_id);
            """).get()

        // Composite index for icon_pack_apps (app_info_id, icon_pack_id) for LEFT JOIN optimization
        _ = try await db.query("""
            CREATE INDEX idx_icon_pack_apps_app_info_icon_pack
            ON icon_pack_apps (app_info_id, icon_pack_id);
            """).get()

        // Index for icon_pack_versions.icon_pack_id (already has unique index but this helps with queries)
        // Note: The unique index on (icon_pack_id, version_string) should already help,
        // but we add a separate index on icon_pack_id alone for better performance
        _ = try await db.query("""
            CREATE INDEX idx_icon_pack_versions_icon_pack_id
            ON icon_pack_versions (icon_pack_id);
            """).get()

        // Index for app_infos.count (used in ORDER BY)
        _ = try await db.query("""
            CREATE INDEX idx_app_infos_count
            ON app_infos (count DESC);
            """).get()

        // GIN indexes for text search using pg_trgm (for ILIKE queries)
        // These support pattern matching with % wildcards
        _ = try await db.query("""
            CREATE INDEX idx_app_infos_default_name_trgm
            ON app_infos USING gin (default_name gin_trgm_ops);
            """).get()

        _ = try await db.query("""
            CREATE INDEX idx_app_infos_package_name_trgm
            ON app_infos USING gin (package_name gin_trgm_ops);
            """).get()

        _ = try await db.query("""
            CREATE INDEX idx_app_infos_main_activity_trgm
            ON app_infos USING gin (main_activity gin_trgm_ops);
            """).get()

        _ = try await db.query("""
            CREATE INDEX idx_app_localized_names_name_trgm
            ON app_localized_names USING gin (name gin_trgm_ops);
            """).get()
    }

    func revert(on database: Database) async throws {
        let db = database as! PostgresDatabase

        _ = try await db.query("DROP INDEX IF EXISTS idx_app_localized_names_app_info_id;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_request_records_app_info_id;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_icon_pack_apps_app_info_icon_pack;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_icon_pack_versions_icon_pack_id;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_app_infos_count;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_app_infos_default_name_trgm;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_app_infos_package_name_trgm;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_app_infos_main_activity_trgm;").get()
        _ = try await db.query("DROP INDEX IF EXISTS idx_app_localized_names_name_trgm;").get()
    }
}
