import Fluent
@preconcurrency import FluentPostgresDriver

/// Migration to create a PostgreSQL trigger that automatically maintains request count for each app.
/// This trigger updates the `count` field in the `app_info` table whenever request records are modified.
struct CreateTrigger: AsyncMigration {
    /// Sets up the trigger and its associated function in the database
    /// - Parameter database: The database connection to use
    /// - Throws: If the SQL queries fail to execute
    func prepare(on database: Database) async throws {
        // Create function that handles count updates
        _ = try await (database as! PostgresDatabase).query("""
        CREATE OR REPLACE FUNCTION update_app_info_request_count()
        RETURNS TRIGGER AS $$
        BEGIN
        IF (TG_OP = 'INSERT') THEN
            UPDATE \(AppInfo.schema)
            SET count = count + 1
            WHERE id = NEW.app_info_id;
        ELSIF (TG_OP = 'DELETE') THEN
            UPDATE \(AppInfo.schema)
            SET count = count - 1
            WHERE id = OLD.app_info_id;
        ELSIF (TG_OP = 'UPDATE') THEN
            IF (OLD.app_info_id != NEW.app_info_id) THEN
            -- Decrement old app_info
            UPDATE \(AppInfo.schema)
            SET count = count - 1
            WHERE id = OLD.app_info_id;
            
            -- Increment new app_info
            UPDATE \(AppInfo.schema)
            SET count = count + 1
            WHERE id = NEW.app_info_id;
            END IF;
        END IF;
        RETURN NULL; -- Since it's an AFTER trigger
        END;
        $$ LANGUAGE plpgsql;
        """).get()

        // Create trigger that calls the function after request record changes
        _ = try await (database as! PostgresDatabase).query("""
        CREATE TRIGGER trg_request_records_after
        AFTER INSERT OR DELETE OR UPDATE ON request_records
        FOR EACH ROW
        EXECUTE FUNCTION update_app_info_request_count();
        """).get()
    }
    
    /// Removes the trigger and its function from the database
    /// - Parameter database: The database connection to use
    /// - Throws: If the SQL queries fail to execute
    func revert(on database: FluentKit.Database) async throws {
        // Drop the trigger
        _ = try await (database as! PostgresDatabase).query("""
        DROP TRIGGER IF EXISTS trg_request_records_after ON request_records;
        """).get()

        // Drop the function
        _ = try await (database as! PostgresDatabase).query("""
        DROP FUNCTION IF EXISTS update_app_info_request_count;
        """).get()
    }
}