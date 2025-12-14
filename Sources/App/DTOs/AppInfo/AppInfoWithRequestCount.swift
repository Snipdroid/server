import SwiftOpenAPI
import Vapor

@OpenAPIDescriptable
struct AppInfoWithRequestCount: Content {
    let appInfo: AppInfoDTO

    /// nil if the requested app is not adapted
    let iconPackApp: IconPackAppDTO?

    /// Number of requests for this app
    let count: Int
}
