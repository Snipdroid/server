import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
struct DesignerStatisticsResponse: Content {
    /// Total number of requests
    let requestCount: Int

    /// Total number of requests with distinct app info and icon pack combination
    /// This means how many icons the designer need to draw to fulfill every request
    let distinctRequestCount: Int
}
