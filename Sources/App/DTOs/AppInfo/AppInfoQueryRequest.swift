import SwiftOpenAPI
import Vapor

@OpenAPIDescriptable
struct AppInfoQueryRequest: Content {
    /// Simple unified search - searches across name, packageName, and mainActivity
    let query: String?

    /// Filter by localized app name (uses similarity matching)
    let byName: String?

    /// Filter by package name (uses ILIKE matching)
    let byPackageName: String?

    /// Filter by main activity (uses ILIKE matching)
    let byMainActivity: String?

    /// Sort order for results, either "relevance" or "count"
    let sortBy: SortOption?

}

enum SortOption: String, Content, CaseIterable, OpenAPIType {
    case relevance
    case count

    static var openAPISchema: SchemaObject {
        SchemaObject(
            description: """
                Sort options for query results:
                • relevance - Sort by similarity/relevance score first, then by count
                • count - Sort by popularity (request count) first (default)
                """,
            enum: allCases.map { AnyValue.string($0.rawValue) },
            context: .string
        )
    }
}
