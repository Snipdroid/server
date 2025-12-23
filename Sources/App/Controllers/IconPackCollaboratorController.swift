import Fluent
import Vapor
import VaporToOpenAPI

struct IconPackCollaboratorController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let collaborators =
            routes
            .grouped("icon-pack", ":iconPackId", "collaborators")
            .grouped(OIDCAuthenticator())

        collaborators
            .get(use: listCollaborators)
            .openAPI(
                summary: "List collaborators",
                description: "Get all collaborators for an icon pack",
                response: .type([DesignerDTO].self)
            )

        collaborators
            .post(use: addCollaborators)
            .openAPI(
                summary: "Add collaborators",
                description: "Add one or more collaborators to an icon pack (owner only)",
                body: .type(IconPack.AddCollaboratorsRequest.self),
                response: .type([DesignerDTO].self)
            )

        collaborators
            .delete(use: removeCollaborators)
            .openAPI(
                summary: "Remove collaborators",
                description: "Remove one or more collaborators from an icon pack (owner only)",
                body: .type(IconPack.RemoveCollaboratorsRequest.self),
                response: .type([DesignerDTO].self)
            )
    }

    // Handler methods
    @Sendable
    func listCollaborators(req: Request) async throws -> [DesignerDTO] {
        let iconPack = try await requireAuthorizedIconPack(
            req: req, on: req.db, requireOwner: false)
        return try await iconPack.$collaborators.query(on: req.db).all().map { $0.toDTO() }
    }

    @Sendable
    func addCollaborators(req: Request) async throws -> [DesignerDTO] {
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let designer = try req.auth.require(Designer.self)

        // Verify owner access
        let iconPack = try await requireAuthorizedIconPack(req: req, on: req.db, requireOwner: true)

        let request = try req.content.decode(IconPack.AddCollaboratorsRequest.self)
        let inviterId = iconPack.$designer.id

        // Validate that all designer IDs exist
        let designers = try await Designer.query(on: req.db)
            .filter(\.$id ~~ request.designerIds)
            .all()

        guard designers.count == request.designerIds.count else {
            throw Abort(.badRequest, reason: "One or more designer IDs are invalid")
        }

        // Get existing collaborators to avoid duplicates
        let existingCollaboratorIds = try await IconPackCollaborators.query(on: req.db)
            .filter(\.$iconPack.$id == iconPackId)
            .all()
            .map { $0.$collaborator.id }

        // Filter out owner and existing collaborators
        let newCollaboratorIds = request.designerIds.filter { id in
            id != inviterId && !existingCollaboratorIds.contains(id)
        }

        // Create pivot records for new collaborators
        for collaboratorId in newCollaboratorIds {
            let pivot = IconPackCollaborators(
                iconPackId: iconPackId,
                collaboratorId: collaboratorId,
                invitedBy: inviterId
            )
            try await pivot.save(on: req.db)
        }

        // Return updated list of all collaborators
        return try await listCollaborators(req: req)
    }

    @Sendable
    func removeCollaborators(req: Request) async throws -> [DesignerDTO] {
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        // Verify owner access
        _ = try await requireAuthorizedIconPack(req: req, on: req.db, requireOwner: true)

        let request = try req.content.decode(IconPack.RemoveCollaboratorsRequest.self)

        // Delete pivot records
        try await IconPackCollaborators.query(on: req.db)
            .filter(\.$iconPack.$id == iconPackId)
            .filter(\.$collaborator.$id ~~ request.designerIds)
            .delete()

        // Return updated list of remaining collaborators
        return try await listCollaborators(req: req)
    }

    // MARK: - Private Helpers

    @Sendable
    private func requireAuthorizedIconPack(req: Request, on db: Database, requireOwner: Bool)
        async throws -> IconPack
    {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard
            let iconPack = try await IconPack.query(on: db)
                .join(
                    IconPackCollaborators.self,
                    on: \IconPack.$id == \IconPackCollaborators.$iconPack.$id, method: .left
                )
                .join(
                    Designer.self, on: \IconPackCollaborators.$collaborator.$id == \Designer.$id,
                    method: .left
                )
                .filter(\IconPack.$id == iconPackId)
                .group(
                    .or,
                    {
                        $0.filter(\.$designer.$id == designerId)
                        if !requireOwner {
                            $0.filter(Designer.self, \.$id == designerId)
                        }
                    }
                )
                .first()
        else {
            throw Abort(.notFound)
        }

        return iconPack
    }
}
