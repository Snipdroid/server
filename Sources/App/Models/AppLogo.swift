import Fluent
import Vapor

struct AppLogo: Content {
    var name: String
    var url: String
    var image: String

    static let placeholder = AppLogo(name: "Placeholder", url: "https://app-tracker.k2t3k.tk", image: "https://raw.githubusercontent.com/Oblatum/App-Tracker-for-Icon-Pack-Web/main/public/placeholder.png")

    func wrapped() -> AppLogo {
        let newImageUrl = "https://download-proxy.butanediol.workers.dev/?url=\(self.image.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self.image )"
        return .init(name: self.name, url: self.url, image: newImageUrl)
    }
}