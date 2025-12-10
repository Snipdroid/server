import Vapor

struct AppInfoWithRequestCount: Content {
    let appInfo: AppInfo
    let count: Int
}
