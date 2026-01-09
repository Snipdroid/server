import SwiftOpenAPI
import Vapor

struct IconPackMarkAppAsAdaptedRequest: Content, OpenAPIType {
    /// A list of app info IDs that are to be marked or unmarked as adapted
    let appInfoIDs: [UUID]

    /// Drawable names for each app, must be the same size as `appInfoIDs` if adapted is true
    let drawables: [UUID: String]

    /// Categories for each app, can be empty
    let categories: [UUID: [String]]

    /// Whether the app should be marked as adapted
    /// If false, the adapted mark will be removed
    let adapted: Bool

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appInfoIDs = try container.decode([UUID].self, forKey: .appInfoIDs)
        self.drawables = Dictionary(
            uniqueKeysWithValues: try container.decode(
                Dictionary<String, String>.self, forKey: .drawables
            )
            .compactMap { (k, v) in UUID(uuidString: k).map { ($0, v) } })
        self.categories = Dictionary(
            uniqueKeysWithValues: try container.decode(
                Dictionary<String, [String]>.self, forKey: .categories
            )
            .compactMap { (k, v) in UUID(uuidString: k).map {
                ($0, v)
            } })
        self.adapted = try container.decode(Bool.self, forKey: .adapted)
    }

    /// Custom OpenAPI schema representation
    static var openAPISchema: SchemaObject {
        SchemaObject(
            description: "Request to mark apps as adapted or remove the adapted mark",
            context: .object(
                ObjectContext(
                    properties: [
                        "appInfoIDs": .array(of: .uuid)
                            .with(
                                \.description,
                                "A list of app info IDs that are to be marked or unmarked as adapted"
                            ),
                        "drawables": .dictionary(of: .string)
                            .with(
                                \.description,
                                "Drawable names for each app. Keys must be UUIDs matching the appInfoIDs. Required when adapted is true."
                            ),
                        "categories": .dictionary(of: .array(of: .string))
                            .with(
                                \.description,
                                "Categories for each app. Keys must be UUIDs matching the appInfoIDs. Can be empty."
                            ),
                        "adapted": .boolean
                            .with(
                                \.description,
                                "Whether the app should be marked as adapted. If false, the adapted mark will be removed"
                            ),
                    ],
                    required: ["appInfoIDs", "drawables", "categories", "adapted"]
                )
            )
        )
    }
}
