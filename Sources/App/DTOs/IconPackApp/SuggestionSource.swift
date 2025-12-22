import Vapor
import VaporToOpenAPI

enum SuggestionSource: String, Codable, CaseIterable, OpenAPIType {
    /// Suggestion comes from the same app of other icon packs by other designers
    case none

    /// Suggestion comes from the same app of the same icon pack
    case iconPack

    /// Suggestion comes from the same app of other icon packs by the same designer
    case designer

    static var openAPISchema: SchemaObject {
        SchemaObject(
            description: """
                Source of the drawable name suggestion:
                • none - From other icon packs by other designers
                • iconPack - From the same icon pack
                • designer - From other icon packs by the same designer
                """,
            enum: allCases.map { AnyValue.string($0.rawValue) },
            context: .string
        )
    }
}
