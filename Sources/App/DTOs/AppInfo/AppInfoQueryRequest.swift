import VaporToOpenAPI
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

enum SortOption: String, Codable, CaseIterable {
    case relevance
    case count
}
