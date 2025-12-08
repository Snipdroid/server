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

    /// Sort order for results
    let sortBy: SortOption?

    @OpenAPIDescriptable
    enum SortOption: String, Content, CaseIterable {
        /// Sort by similarity/relevance score first, then by count
        case relevance
        /// Sort by popularity (request count) first (default)
        case count
    }
}
