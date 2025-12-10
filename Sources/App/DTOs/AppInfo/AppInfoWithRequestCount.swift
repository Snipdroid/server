import Vapor

struct AppInfoWithRequestCount: Content {
    let appInfo: AppInfoDTO
    let count: Int
}
