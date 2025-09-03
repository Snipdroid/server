# Database Schema DDL

This directory contains PostgreSQL DDL (Data Definition Language) for the Snipdroid Server database tables.

## Files

- **`database_schema.sql`** - Complete PostgreSQL DDL with detailed comments and documentation
- **`Scripts/generate_ddl.swift`** - Dynamic DDL generator script

## Tables Included

### app_infos
Stores application information including package details.

**Columns:**
- `id` - UUID primary key  
- `default_name` - Default display name for the app
- `package_name` - Android package name (e.g., com.example.app)
- `main_activity` - Main activity class name
- `created_at` - Creation timestamp (auto-managed)
- `count` - Request count for this app (default: 0)

### app_localized_names
Stores localized names for applications in different languages.

**Columns:**
- `id` - UUID primary key
- `app_info_id` - Foreign key to app_infos table
- `language_code` - Language/locale code (e.g., en, es, fr)
- `name` - Localized name for the app
- `is_primary` - Whether this is the primary name for the language
- `created_at` - Creation timestamp (auto-managed)
- `updated_at` - Last update timestamp (auto-managed)

## Usage

### Using the Complete DDL File
```bash
# Apply the complete schema
psql -d your_database -f database_schema.sql
```

### Using the DDL Generator Script
```bash
# Generate complete DDL
swift Scripts/generate_ddl.swift all

# Generate specific tables
swift Scripts/generate_ddl.swift app_infos
swift Scripts/generate_ddl.swift app_localized_names

# Generate only indexes
swift Scripts/generate_ddl.swift indexes

# Show help
swift Scripts/generate_ddl.swift --help
```

## Notes

1. **UUID Generation**: The DDL uses `gen_random_uuid()` which requires the `pgcrypto` extension. If not available, you can use `uuid_generate_v4()` with the `uuid-ossp` extension.

2. **Indexes**: The schema includes recommended indexes for common query patterns. Adjust based on your specific use cases.

3. **Timestamps**: The `created_at` and `updated_at` timestamps are automatically managed by the Fluent ORM in the application.

4. **Foreign Keys**: The relationship between `app_localized_names` and `app_infos` is enforced through foreign key constraints.

## Source

This DDL is generated from the Fluent migrations defined in:
- `Sources/App/Models/AppInfo.swift` - CreateAppInfo migration
- `Sources/App/Models/AppLocalizedName.swift` - CreateAppLocalizedName migration