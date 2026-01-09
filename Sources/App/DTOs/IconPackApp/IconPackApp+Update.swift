import Vapor

extension IconPackApp {
    struct Update: Content {
        let categories: [String]
    }
}
