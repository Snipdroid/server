import Fluent
import Vapor
import VaporToOpenAPI

struct TagController: RouteCollection {
	func boot(routes: any Vapor.RoutesBuilder) throws {
		let tags = routes.grouped("tags")

		tags.get(use: listTags)
			.openAPI(
				summary: "List all tags",
				description: "List all tags",
				response: .type([TagDTO].self)
			)

	}

	@Sendable
	func listTags(_ req: Request) async throws -> [TagDTO] {
		try await Tag.query(on: req.db).all().map { $0.toDTO() }
	}
}
