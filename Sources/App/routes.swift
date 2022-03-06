import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws -> String in
        return "Yes! It's up and running!"
    }

    try app.register(collection: AppInfoController())
    try app.register(collection: AppIconController())
    try app.register(collection: SignatureAppInfoController())

    app.on(.GET, "api", "icon") { req async throws -> AppLogo in
        guard let appId: String = req.query["appId"],
            let packageName = appId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { throw Abort(.badRequest) }

        // Local database
        if let buffer = try? await req.fileio.collectFile(at: "data/icons/\(packageName).jpg"), buffer.readableBytes > 0 {
            req.logger.info("Find local icon file.")
            return .init(name: "", url: "", image: "https://bot.k2t3k.tk/api/appIcon?packageName=\(packageName)")
        }

        // Coolapk
        var response = try await req.client.get("https://www.coolapk.com/apk/\(packageName)")

        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let iconUrlRegex = try NSRegularExpression(pattern: #"<div\sclass="apk_topbar">\s+<img\ssrc="(https?:\/\/.+)\s">\s+<div\sclass="apk_topba_appinfo">"#, options: .anchorsMatchLines)
            let matches = iconUrlRegex.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1..<match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    let urlString = String(data: data, encoding: .utf8)!
                    req.logger.info("Use icon from coolapk.com")
                    return .init(name: "", url: "", image: urlString).wrapped()
                }
            }
        }

        // Google Play
        response = try await req.client.get("https://play.google.com/store/apps/details?id=\(packageName)&hl=zh&gl=us")
        
        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let jsonRegex = try NSRegularExpression(pattern: #"<script\stype="application\/ld\+json"\snonce="(?:\S+)">([^<]+)<\/script>"#, options: .anchorsMatchLines)
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = jsonRegex.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1 ..< match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    req.logger.info("Use icon from play.google.com")
                    return try JSONDecoder().decode(AppLogo.self, from: data).wrapped()
                }
            }    
        }        

        return AppLogo.placeholder
    }
}
