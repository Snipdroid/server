import Fluent
import FluentDTOMacro
import Vapor

@FluentDTO
final class AppInfoTag: Model, Content, @unchecked Sendable {
	static let schema = "app_info+tag"

	@ID(key: .id)
	var id: UUID?

	@Parent(key: "app_info_id")
	var appInfo: AppInfo

	@Parent(key: "tag_id")
	var tag: Tag

	@Parent(key: "created_by")
	var createdBy: Designer

	@Timestamp(key: "created_at", on: .create)
	var createdAt: Date?

	init() {}

	init(id: UUID? = nil, appInfo: AppInfo, tag: Tag, createdBy: Designer) throws {
		self.id = id
		self.$appInfo.id = try appInfo.requireID()
		self.$tag.id = try tag.requireID()
		self.$createdBy.id = try createdBy.requireID()
	}
}

struct CreateAppInfoTag: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(AppInfoTag.schema)
			.id()
			.field(
				AppInfoTag.fieldKey(for: \.$appInfo), .uuid, .required,
				.references(AppInfo.schema, .id, onDelete: .cascade)
			)
			.field(
				AppInfoTag.fieldKey(for: \.$tag), .uuid, .required,
				.references(Tag.schema, .id, onDelete: .cascade)
			)
			.field(
				AppInfoTag.fieldKey(for: \.$createdBy), .uuid, .required,
				.references(Designer.schema, .id, onDelete: .cascade)
			)
			.field(AppInfoTag.fieldKey(for: \.$createdAt), .datetime)
			.create()

		#warning(
			"TODO: When designer account is deleted, the `createdBy` field should be set to a unique value"
		)
	}

	func revert(on database: Database) async throws {
		try await database.schema(AppInfoTag.schema).delete()
	}
}
