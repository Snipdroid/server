import Fluent
import Vapor

struct PlayApp: Content {
    var name: String
    var url: String
    var image: String

    static let placeholder = PlayApp(name: "Placeholder", url: "https://app-tracker.k2t3k.tk", image: "https://app-tracker.k2t3k.tk/static/placeholder.gif")
}