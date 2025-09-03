#!/usr/bin/env swift

// DDL Generator for Snipdroid Server
// Extracts PostgreSQL DDL from Fluent migration definitions

import Foundation

struct DDLGenerator {
    
    static func generateAppInfosDDL() -> String {
        return """
        -- Table: app_infos
        CREATE TABLE app_infos (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            default_name VARCHAR NOT NULL,
            package_name VARCHAR NOT NULL,
            main_activity VARCHAR NOT NULL,
            created_at TIMESTAMP,
            count INTEGER NOT NULL DEFAULT 0
        );
        """
    }
    
    static func generateAppLocalizedNamesDDL() -> String {
        return """
        -- Table: app_localized_names
        CREATE TABLE app_localized_names (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            app_info_id UUID REFERENCES app_infos(id),
            language_code VARCHAR NOT NULL,
            name VARCHAR NOT NULL,
            is_primary BOOLEAN NOT NULL,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        );
        """
    }
    
    static func generateIndexes() -> String {
        return """
        -- Recommended indexes for performance
        CREATE INDEX idx_app_localized_names_app_info_id ON app_localized_names(app_info_id);
        CREATE INDEX idx_app_localized_names_language_code ON app_localized_names(language_code);
        CREATE INDEX idx_app_localized_names_is_primary ON app_localized_names(is_primary);
        CREATE INDEX idx_app_localized_names_app_lang ON app_localized_names(app_info_id, language_code);
        """
    }
    
    static func generateFullDDL() -> String {
        let header = """
        -- PostgreSQL DDL for Snipdroid Server
        -- Generated from Fluent migrations
        -- Tables: app_infos, app_localized_names
        
        """
        
        return header + 
               generateAppInfosDDL() + "\n\n" +
               generateAppLocalizedNamesDDL() + "\n\n" +
               generateIndexes()
    }
}

// Command line interface
if CommandLine.arguments.count > 1 {
    let command = CommandLine.arguments[1]
    
    switch command {
    case "app_infos":
        print(DDLGenerator.generateAppInfosDDL())
    case "app_localized_names":
        print(DDLGenerator.generateAppLocalizedNamesDDL())
    case "indexes":
        print(DDLGenerator.generateIndexes())
    case "all", "--all":
        print(DDLGenerator.generateFullDDL())
    case "--help", "-h":
        print("""
        DDL Generator for Snipdroid Server
        
        Usage: swift generate_ddl.swift [command]
        
        Commands:
          app_infos              Generate DDL for app_infos table only
          app_localized_names    Generate DDL for app_localized_names table only  
          indexes               Generate recommended indexes only
          all                   Generate complete DDL (default)
          --help, -h            Show this help message
        
        Examples:
          swift generate_ddl.swift all
          swift generate_ddl.swift app_infos
          swift generate_ddl.swift indexes
        """)
    default:
        print("Unknown command: \(command). Use --help for usage information.")
        exit(1)
    }
} else {
    // Default: generate full DDL
    print(DDLGenerator.generateFullDDL())
}