import SwiftOpenAPI
import Vapor

@OpenAPIDescriptable
struct IconPackMarkAppAsAdaptedRequest: Content {
    /// A list of app info IDs that are to be marked or unmarked as adapted
    let appInfoIDs: [UUID]

    /// Drawable names for each app, must be the same size as `appInfoIDs` if adapted is true
    let drawables: [UUID: String]

    /// Whether the app should be marked as adapted
    /// If false, the adapted mark will be removed
    let adapted: Bool
}
