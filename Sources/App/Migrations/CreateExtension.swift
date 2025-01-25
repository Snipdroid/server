import Fluent
@preconcurrency import FluentPostgresDriver

struct CreateExtension: AsyncMigration {
    func prepare(on database: Database) async throws {
        _ = try await (database as! PostgresDatabase).query("CREATE EXTENSION pg_trgm;").get()
    }
    
    func revert(on database: FluentKit.Database) async throws {
        _ = try await (database as! PostgresDatabase).query("DROP EXTENSION IF EXISTS pg_trgm;").get()
    }
}