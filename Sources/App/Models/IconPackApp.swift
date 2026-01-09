import Fluent
import FluentDTOMacro
import Vapor

/// This table is store which apps does an icon pack has adapted.
@FluentDTO
final class IconPackApp: Model, @unchecked Sendable {
	static let schema = "icon_pack_apps"

	@ID(key: .id)
	var id: UUID?

	@Parent(key: "icon_pack_id")
	var iconPack: IconPack

	@Parent(key: "app_info_id")
	var appInfo: AppInfo

	@Field(key: "drawable")
	var drawable: String

	@Timestamp(key: "created_at", on: .create)
	var createdAt: Date?

	@Timestamp(key: "updated_at", on: .update)
	var updatedAt: Date?

	@Field(key: "categories")
	var categories: [String]

	init() {}

	init(id: UUID? = nil, iconPack: IconPack, appInfo: AppInfo, drawable: String) throws {
		self.id = id
		self.$iconPack.id = try iconPack.requireID()
		self.$appInfo.id = try appInfo.requireID()
		self.drawable = drawable
		self.categories = []
	}
}

extension IconPackAppDTO: Content {}

struct CreateIconPackApp: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(IconPackApp.schema)
			.id()
			.field(
				"icon_pack_id", .uuid, .required,
				.references(IconPack.schema, "id", onDelete: .cascade)
			)
			.field(
				"app_info_id", .uuid, .required,
				.references(AppInfo.schema, "id", onDelete: .cascade)
			)
			.field("drawable", .string, .required)
			.field("created_at", .datetime)
			.field("updated_at", .datetime)
			.field("categories", .array(of: .string), .required, .sql(.default("{}")))
			.unique(on: "icon_pack_id", "app_info_id")
			.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema(IconPackApp.schema).delete()
	}
}
