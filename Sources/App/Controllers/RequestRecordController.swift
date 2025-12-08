import Vapor
import VaporToOpenAPI
import Fluent

struct RequestRecordController: RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        let requestRecord = routes.grouped("request-record")

        requestRecord
            .grouped(OIDCAuthenticator())
            .delete(":requestRecordId", use: deleteRequest)
            .openAPI(
                summary: "Delete request",
                description: "Delete a request record",
                response: .type(HTTPStatus.self)
            )
    }

    // DELETE /request-record/:requestRecordId
    @Sendable
    func deleteRequest(req: Request) async throws -> HTTPStatus {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()
        
        let requestRecordId = try req.parameters.require("requestRecordId", as: UUID.self)

        guard let requestRecord = try await RequestRecord.query(on: req.db)
            .filter(\.$id == requestRecordId)
            .with(\.$iconPackVersion)
            .first() else {
            throw Abort(.notFound)
        }

        guard requestRecord.iconPackVersion?.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        try await requestRecord.delete(on: req.db)
        return .ok
    }
}