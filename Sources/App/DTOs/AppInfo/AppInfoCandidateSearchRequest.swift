import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
struct AppInfoCandidateSearchRequest: Content {
    /// Array of package names to search for
    /// Note: Results may include apps matching ANY package name in this array
    let packageNames: [String]

    /// Array of main activity names to search for
    /// Note: Results may include apps matching ANY main activity in this array
    /// ⚠️ The search returns candidates where packageName ∈ packageNames AND mainActivity ∈ mainActivities,
    /// which may include false positives (apps with unintended packageName/mainActivity pairings)
    let mainActivities: [String]
}
