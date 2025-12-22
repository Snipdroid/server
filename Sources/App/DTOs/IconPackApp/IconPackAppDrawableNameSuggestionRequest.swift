import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
struct IconPackAppDrawableNameSuggestionRequest: Content {
    let iconPackID: UUID?
    let designerID: UUID?
    let packageName: String
}
