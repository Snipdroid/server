import SwiftOpenAPI
import Vapor

@OpenAPIDescriptable
struct IconPackMarkAppAsAdaptedRequest: Content {
    /// A list of app info IDs that are to be marked or unmarked as adapted
    let appInfoIDs: [UUID]

    /// Whether the app should be marked as adapted
    /// If false, the adapted mark will be removed
    let adapted: Bool
}
