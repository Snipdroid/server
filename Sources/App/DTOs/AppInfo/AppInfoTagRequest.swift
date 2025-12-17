import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
struct AppInfoTagRequest: Content {
    /// The ID of the tag, can be retrieved from the `/tags` endpoint
    let tagID: UUID

    /// Whether to remove the tag from the app
    /// - `true` to remove the tag
    /// - `false` to add the tag
    let remove: Bool
}
