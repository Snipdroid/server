-- PostgreSQL DDL for Snipdroid Server Tables
-- Generated from Fluent migrations in Sources/App/Models/
-- Author: GitHub Copilot
-- Date: 2024

-- =============================================================================
-- Table: app_infos
-- =============================================================================
-- Description: Stores application information including package details
-- Source: AppInfo model and CreateAppInfo migration
-- Schema: app_infos

CREATE TABLE app_infos (
    -- Primary key - UUID with auto-generation
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Application details
    default_name VARCHAR NOT NULL,              -- Default display name for the app
    package_name VARCHAR NOT NULL,              -- Android package name (e.g., com.example.app)
    main_activity VARCHAR NOT NULL,             -- Main activity class name
    
    -- Metadata
    created_at TIMESTAMP,                       -- Creation timestamp (auto-managed)
    count INTEGER NOT NULL DEFAULT 0            -- Request count for this app
);

-- =============================================================================
-- Table: app_localized_names
-- =============================================================================
-- Description: Stores localized names for applications in different languages
-- Source: AppLocalizedName model and CreateAppLocalizedName migration  
-- Schema: app_localized_names

CREATE TABLE app_localized_names (
    -- Primary key - UUID with auto-generation
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key to app_infos table
    app_info_id UUID REFERENCES app_infos(id),
    
    -- Localization details
    language_code VARCHAR NOT NULL,             -- Language/locale code (e.g., en, es, fr)
    name VARCHAR NOT NULL,                      -- Localized name for the app
    is_primary BOOLEAN NOT NULL,                -- Whether this is the primary name for the language
    
    -- Metadata
    created_at TIMESTAMP,                       -- Creation timestamp (auto-managed)
    updated_at TIMESTAMP                        -- Last update timestamp (auto-managed)
);

-- =============================================================================
-- Recommended Indexes
-- =============================================================================
-- These indexes can improve query performance based on common access patterns

-- Index for foreign key lookups
CREATE INDEX idx_app_localized_names_app_info_id ON app_localized_names(app_info_id);

-- Index for language-based queries
CREATE INDEX idx_app_localized_names_language_code ON app_localized_names(language_code);

-- Index for finding primary names
CREATE INDEX idx_app_localized_names_is_primary ON app_localized_names(is_primary);

-- Composite index for efficient localization lookups
CREATE INDEX idx_app_localized_names_app_lang ON app_localized_names(app_info_id, language_code);

-- =============================================================================
-- Additional Constraints (Optional)
-- =============================================================================
-- These constraints can be added for data integrity if needed

-- Ensure only one primary name per app per language
-- CREATE UNIQUE INDEX idx_app_localized_names_unique_primary 
--     ON app_localized_names(app_info_id, language_code) 
--     WHERE is_primary = true;

-- Ensure package names are unique (if business logic requires it)
-- ALTER TABLE app_infos ADD CONSTRAINT unique_package_name UNIQUE (package_name);

-- =============================================================================
-- Notes
-- =============================================================================
-- 1. UUID generation uses gen_random_uuid() which requires the pgcrypto extension
--    If not available, you can use uuid_generate_v4() with the uuid-ossp extension
-- 2. Timestamps are managed automatically by the Fluent ORM
-- 3. The foreign key relationship ensures referential integrity between tables
-- 4. Consider adding appropriate indexes based on your query patterns