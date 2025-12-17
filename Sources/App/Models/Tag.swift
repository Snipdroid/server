import Fluent
import FluentDTOMacro
import Vapor

@FluentDTO
final class Tag: Model, Content, @unchecked Sendable {
	static let schema = "tags"

	@ID(key: .id)
	var id: UUID?

	@Field(key: "name")
	var name: String

	@Field(key: "description")
	var description: String?

	@Siblings(through: AppInfoTag.self, from: \.$tag, to: \.$appInfo)
	var appInfos: [AppInfo]

	@Timestamp(key: "created_at", on: .create)
	var createdAt: Date?

	init() {}
}

extension TagDTO: Content {}

struct CreateTag: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(Tag.schema)
			.id()
			.field(Tag.fieldKey(for: \.$name), .string, .required)
			.field(Tag.fieldKey(for: \.$description), .string)
			.field(Tag.fieldKey(for: \.$createdAt), .datetime)
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema(Tag.schema).delete()
	}
}
