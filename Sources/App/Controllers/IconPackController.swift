import Fluent
import Vapor
import VaporToOpenAPI

struct IconPackController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let iconPacks =
            routes
            .grouped("icon-pack")
            .grouped(OIDCAuthenticator())

        iconPacks
            .post("create", use: create)
            .openAPI(
                summary: "Create icon pack",
                description: "Create a new icon pack",
                body: .type(IconPack.Create.self),
                response: .type(IconPackDTO.self)
            )

        iconPacks
            .get(use: list)
            .openAPI(
                summary: "List icon packs",
                description: "List all icon packs for the authenticated designer",
                response: .type([IconPackDTO].self)
            )

        iconPacks
            .get(":iconPackId", use: get)
            .openAPI(
                summary: "Get icon pack",
                description:
                    """
                    Get a specific icon pack by ID,
                    does not include its icon pack verisons,
                    use `/icon-pack/:iconPackId/versions` instead
                    """,
                response: .type(IconPackDTO.self)
            )

        iconPacks
            .put(":iconPackId", use: update)
            .openAPI(
                summary: "Update icon pack",
                description: "Update an icon pack's name",
                body: .type(IconPack.Update.self),
                response: .type(IconPackDTO.self)
            )

        iconPacks
            .delete(":iconPackId", use: delete)
            .openAPI(
                summary: "Delete icon pack",
                description: "Delete an icon pack and all its versions",
                response: .type(HTTPStatus.self)
            )

        iconPacks
            .post(":iconPackId", use: markAsAdapted)
            .openAPI(
                summary: "Mark app as adapted",
                description: "Mark an app as adapted, or remove the adapted mark",
                body: .type(IconPackMarkAppAsAdaptedRequest.self),
                response: .type([IconPackAppDTO].self)
            )

        routes.get("icon-pack", ":iconPackId", "adapted-apps", use: getAdaptedApps)
            .openAPI(
                summary: "Get adapted apps",
                description: "Get the list of apps that have been adapted",
                query: .type(PageRequest.self),
                response: .type(Page<AppInfoDTO>.self)
            )
    }

    @Sendable
    func create(req: Request) async throws -> IconPackDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let create = try req.content.decode(IconPack.Create.self)

        // Ensure the icon pack name doesn't already exist for this designer
        guard
            try await IconPack.query(on: req.db)
                .filter(\.$designer.$id == designerId)
                .filter(\.$name == create.name)
                .first() == nil
        else {
            throw InternalError.violationOfUniqueConstraint(IconPack.self)
        }

        let iconPack = IconPack(designerId: designerId, name: create.name)
        try await iconPack.save(on: req.db)

        return iconPack.toDTO()
    }

    @Sendable
    func list(req: Request) async throws -> [IconPackDTO] {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPacks = try await IconPack.query(on: req.db)
            .filter(\.$designer.$id == designerId)
            .all()

        return iconPacks.map { $0.toDTO() }
    }

    @Sendable
    func get(req: Request) async throws -> IconPackDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        return iconPack.toDTO()
    }

    @Sendable
    func update(req: Request) async throws -> IconPackDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let update = try req.content.decode(IconPack.Update.self)

        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        // Check if new name conflicts with existing icon pack
        if iconPack.name != update.name {
            guard
                try await IconPack.query(on: req.db)
                    .filter(\.$designer.$id == designerId)
                    .filter(\.$name == update.name)
                    .first() == nil
            else {
                throw InternalError.violationOfUniqueConstraint(IconPack.self)
            }
        }

        iconPack.name = update.name
        try await iconPack.save(on: req.db)

        return iconPack.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        try await iconPack.delete(on: req.db)

        return .noContent
    }

    @Sendable
    func markAsAdapted(req: Request) async throws -> [IconPackAppDTO] {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let markRequest = try req.content.decode(IconPackMarkAppAsAdaptedRequest.self)

        return try await req.db.transaction { db in
            // Get the icon pack
            guard
                let iconPack = try await IconPack.query(on: db)
                    .filter(\.$id == iconPackId)
                    .first()
            else {
                throw Abort(.notFound, reason: "Icon pack not found")
            }

            // Ensure the icon pack belongs to the authenticated designer
            guard iconPack.$designer.id == designerId else {
                throw Abort(
                    .forbidden, reason: "Icon pack does not belong to the authenticated designer")
            }

            // Get the app
            let appInfoList = try await AppInfo.query(on: db)
                .filter(\.$id ~~ markRequest.appInfoIDs)
                .all()

            if markRequest.adapted {
                try await iconPack.$adaptedApps.attach(appInfoList, on: db)
            } else {
                try await iconPack.$adaptedApps.detach(appInfoList, on: db)
            }

            return try await IconPackApp.query(on: db)
                .filter(\.$iconPack.$id == iconPackId)
                .filter(\.$appInfo.$id ~~ markRequest.appInfoIDs)
                .all()
                .map { $0.toDTO() }
        }
    }

    @Sendable
    func getAdaptedApps(req: Request) async throws -> Page<AppInfoDTO> {
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard
            let iconPack =
                try await IconPack
                .query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound, reason: "Icon pack not found")
        }

        return try await iconPack.$adaptedApps.query(on: req.db)
            .paginate(for: req).map {
                $0.toDTO()
            }
    }
}
