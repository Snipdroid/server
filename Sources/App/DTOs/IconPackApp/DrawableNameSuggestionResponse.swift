import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
struct DrawableNameSuggestionResponse: Content {
    /// Drawable name suggestion
    let drawable: String

    /// Where this suggestion comes from
    let from: SuggestionSource
}
