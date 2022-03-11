import Fluent
import Vapor

struct IconPathRegex {
    static let googlePlay = try! NSRegularExpression(pattern: #"<script\stype="application\/ld\+json"\snonce="(?:\S+)">([^<]+)<\/script>"#, options: .anchorsMatchLines)
    static let coolapk = try! NSRegularExpression(pattern: #"<div\sclass="apk_topbar">\s+<img\ssrc="(https?:\/\/.+)\s">\s+<div\sclass="apk_topba_appinfo">"#, options: .anchorsMatchLines)
    static let mi = try! NSRegularExpression(pattern: #"<img\sclass="yellow-flower"\ssrc="(https?:\/\/\S+)"\salt="(\S+)"\swidth="\d+"\sheight="\d+">"#, options: .anchorsMatchLines)
}

struct IconController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let icon = routes.grouped("api", "icon")

        icon.get(use: getIcon)
    }

    private func getIcon(req: Request) async throws -> AppLogo {
        guard let appId: String = req.query["appId"],
            let packageName = appId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { throw Abort(.badRequest) }

        if let icon = try await getLocalIcon(req: req, packageName: packageName) {
            return icon
        } else if let icon = try await getIconFromMi(req: req, packageName: packageName) {
            return icon
        } else if let icon = try await getIconFromCoolapk(req: req, packageName: packageName) {
            return icon
        } else if let icon = try await getIconFromGooglePlay(req: req, packageName: packageName) {
            return icon
        }

        return AppLogo.placeholder
    }

    private func getLocalIcon(req: Request, packageName: String) async throws -> AppLogo? {
        // Local database
        if let buffer = try? await req.fileio.collectFile(at: "data/icons/\(packageName).jpg"), buffer.readableBytes > 0 {
            req.logger.info("Find local icon file.")
            return .init(name: "", url: "", image: "https://bot.k2t3k.tk/api/appIcon?packageName=\(packageName)")
        }
        return nil
    }

    private func getIconFromGooglePlay(req: Request, packageName: String) async throws -> AppLogo? {
        // Google Play
        let response = try await req.client.get("https://play.google.com/store/apps/details?id=\(packageName)&hl=zh&gl=us")
        
        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = IconPathRegex.googlePlay.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1 ..< match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    req.logger.info("Use icon from play.google.com")
                    return try JSONDecoder().decode(AppLogo.self, from: data).wrapped()
                }
            }    
        } 
        return nil
    }

    private func getIconFromCoolapk(req: Request, packageName: String) async throws -> AppLogo? {
        let response = try await req.client.get("https://www.coolapk.com/apk/\(packageName)")

        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = IconPathRegex.coolapk.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1..<match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    let urlString = String(data: data, encoding: .utf8)!
                    req.logger.info("Use icon from coolapk.com")
                    return .init(name: "", url: "", image: urlString).wrapped()
                }
            }
        }
        return nil
    }

    private func getIconFromMi(req: Request, packageName: String) async throws -> AppLogo? {
        let response = try await req.client.get("https://app.mi.com/details?id=\(packageName)")

        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = IconPathRegex.mi.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1..<match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    let urlString = String(data: data, encoding: .utf8)!
                    req.logger.info("Use icon from app.mi.com")
                    return .init(name: "", url: "", image: urlString).wrapped()
                }
            }
        }
        return nil
    }

}