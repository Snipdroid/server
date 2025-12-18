# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AppTracker is a REST API backend built with Swift 6 and the Vapor framework. It manages application information and icon pack versions for designers, with JWT authentication, PostgreSQL persistence, and AWS S3-compatible storage.

## Build & Development Commands

```bash
# Local development (requires Swift 6.1+)
swift build                    # Build the project
swift build -c release         # Production build
swift test                     # Run tests

# Docker-based development
docker compose build           # Build images
docker compose up db -d        # Start PostgreSQL
docker compose run migrate     # Run database migrations
docker compose up app -d       # Start the application
docker compose run revert      # Revert migrations
docker compose down -v         # Stop services and remove volumes
```

The API runs at `http://localhost:8080`.

## Architecture

```
Sources/App/
├── configure.swift           # App configuration (DB, JWT, AWS, routes)
├── entrypoint.swift          # Async main entry point
├── routes.swift              # Route registration
├── Controllers/              # RouteCollection controllers
├── Models/                   # Fluent ORM models (Designer, AppInfo, IconPackVersion, etc.)
├── DTOs/                     # Request/response data transfer objects
├── Migrations/               # Database schema migrations
├── Middlewares/Authentication/  # JWT bearer token authenticators
├── Extensions/               # Application & Request extensions for AWS
├── Jobs/                     # Redis-based background jobs
└── Misc/Errors.swift         # Custom InternalError enum
```

**Key patterns:**
- Controllers implement `RouteCollection` protocol
- Models use Fluent's `@ID`, `@Field`, `@Parent`, `@Children` property wrappers
- DTOs separate API contracts from database models
- Authentication uses `ModelAuthenticatable` and `BearerAuthenticator`

## Dependencies

- **Vapor**: Web framework
- **Fluent + FluentPostgresDriver**: ORM with PostgreSQL
- **JWT**: Authentication tokens
- **QueuesRedisDriver**: Background job queue
- **Soto (SotoS3)**: AWS S3-compatible storage
- **VaporToOpenAPI**: API documentation generation

## Environment Variables

```
DATABASE_HOST, DATABASE_NAME, DATABASE_USERNAME, DATABASE_PASSWORD
JWT_SECRET
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT
LOG_LEVEL
```

## API Documentation

OpenAPI spec is automatically generated, it can be accessed by `http://localhost:8080/swagger`
