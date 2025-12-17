import Fluent
import Vapor
import VaporToOpenAPI

struct TagController: RouteCollection {
	func boot(routes: any Vapor.RoutesBuilder) throws {
		let tags = routes.grouped("tags")

		tags.get(use: listTags)
	}

	@Sendable
	func listTags(_ req: Request) async throws -> [TagDTO] {
		try await Tag.query(on: req.db).all().map { $0.toDTO() }
	}
}
