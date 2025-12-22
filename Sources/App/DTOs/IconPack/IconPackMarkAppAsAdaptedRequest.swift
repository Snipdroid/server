import SwiftOpenAPI
import Vapor

struct IconPackMarkAppAsAdaptedRequest: Content, OpenAPIType {
    /// A list of app info IDs that are to be marked or unmarked as adapted
    let appInfoIDs: [UUID]

    /// Drawable names for each app, must be the same size as `appInfoIDs` if adapted is true
    let drawables: [UUID: String]

    /// Whether the app should be marked as adapted
    /// If false, the adapted mark will be removed
    let adapted: Bool

    /// Custom OpenAPI schema representation
    static var openAPISchema: SchemaObject {
        SchemaObject(
            description: "Request to mark apps as adapted or remove the adapted mark",
            context: .object(
                ObjectContext(
                    properties: [
                        "appInfoIDs": .array(of: .uuid)
                            .with(\.description, "A list of app info IDs that are to be marked or unmarked as adapted"),
                        "drawables": .dictionary(of: .string)
                            .with(
                                \.description,
                                "Drawable names for each app. Keys must be UUIDs matching the appInfoIDs. Required when adapted is true."
                            ),
                        "adapted": .boolean
                            .with(
                                \.description,
                                "Whether the app should be marked as adapted. If false, the adapted mark will be removed"
                            ),
                    ],
                    required: ["appInfoIDs", "drawables", "adapted"]
                )
            )
        )
    }
}
