import Fluent
import Vapor

struct IconPathRegex {
    static let googlePlay = try! NSRegularExpression(pattern: #"<meta\sproperty="og:image"\scontent="(https:\/\/play-lh\.googleusercontent\.com\/(?:\w|-)+)">"#, options: .anchorsMatchLines)
    static let coolapk = try! NSRegularExpression(pattern: #"<div\sclass="apk_topbar">\s+<img\ssrc="(https?:\/\/.+)\s">\s+<div\sclass="apk_topba_appinfo">"#, options: .anchorsMatchLines)
    static let mi = try! NSRegularExpression(pattern: #"<img\sclass="yellow-flower"\ssrc="(https?:\/\/\S+)"\salt="(\S+)"\swidth="\d+"\sheight="\d+">"#, options: .anchorsMatchLines)
}

struct IconController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let icon = routes.grouped("api", "icon")

        icon.get("local", use: getLocalIcon)
        icon.get("play", use: getIconFromGooglePlay)
        icon.get("mi", use: getIconFromMi)
        icon.get("coolapk", use: getIconFromCoolapk)

        icon.get(use: getIcon)
        icon.on(.POST, body: .collect(maxSize: "1mb"), use: newIcon)

    }

    func getIcon(req: Request) async throws -> Response {
        // GET /api/appIcon?packageName=
        guard let packageName: String = req.query["packageName"] else {
            throw Abort(.notEnoughArguments("packageName"))
        }

        let data = try await req.application.iconProvider.getIcon(from: packageName)
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "image/png")
        return .init(status: .ok, headers: headers, body: .init(data: data))
    }

    func newIcon(req: Request) async throws -> RequestResult {
        // POST /api/appIcon?packageName=
        guard req.headers["Content-Type"].contains("image/png"), 
            let packageName: String = req.query["packageName"],
            let buffer = req.body.data else {        
            throw Abort(
                .either(.notEnoughArguments("packageName"), .contentError("image buffer"))
            )
        }
        let data = Data(buffer: buffer)
        try await req.application.iconProvider.saveIcon(data, for: packageName.lowercased())
        return .init(code: 200, isSuccess: true, message: "Added/updated new app icon.")
    }

    let placeholder = "https://raw.githubusercontent.com/Oblatum/App-Tracker-for-Icon-Pack-Web/main/public/placeholder.png"

    private func getPakcageName(from req: Request) throws -> String {
        guard let packageName =
            (req.query["packageName"] as String?)?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            throw Abort(.notEnoughArguments("packageName"))
        }
        return packageName
    }

    private func getLocalIcon(req: Request) async throws -> Response {
        let packageName = try getPakcageName(from: req)
        let url = try await req.application.iconProvider.getIconUrl(packageName: packageName)
        return req.redirect(to: url)
    }

    private func getIconFromGooglePlay(req: Request) async throws -> Response {
        // Google Play
        let packageName = try getPakcageName(from: req)
        let response = try await req.client.get("https://play.google.com/store/apps/details?id=\(packageName)&hl=zh&gl=us")

        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = IconPathRegex.googlePlay.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1 ..< match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    let urlString = String(data: data, encoding: .utf8)!
                    return req.redirect(to: urlString)
                }
            }
        }
        return req.redirect(to: placeholder)
    }

    private func getIconFromCoolapk(req: Request) async throws -> Response {
        let packageName = try getPakcageName(from: req)
        let response = try await req.client.get("https://www.coolapk.com/apk/\(packageName)")

        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = IconPathRegex.coolapk.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1 ..< match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    let urlString = String(data: data, encoding: .utf8)!
                    return req.redirect(to: urlString)
                }
            }
        }
        return req.redirect(to: placeholder)
    }

    private func getIconFromMi(req: Request) async throws -> Response {
        let packageName = try getPakcageName(from: req)
        let response = try await req.client.get("https://app.mi.com/details?id=\(packageName)")

        if var body = response.body, let html = body.readString(length: body.readableBytes) {
            let htmlRange = NSRange(location: 0, length: html.utf16.count)
            let matches = IconPathRegex.mi.matches(in: html, range: htmlRange)
            for match in matches {
                for rangeIndex in 1 ..< match.numberOfRanges {
                    let data = (html as NSString).substring(with: match.range(at: rangeIndex)).data(using: .utf8)!
                    let urlString = String(data: data, encoding: .utf8)!
                    return req.redirect(to: urlString)
                }
            }
        }
        return req.redirect(to: placeholder)
    }
}
