import Fluent
import Vapor

struct AppImageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appIcons = routes.grouped("api", "appIcon")

        appIcons.get(use: getIcon)
        appIcons.on(.POST, body: .collect(maxSize: "1mb"), use: newIcon)
    }

    func getIcon(req: Request) async throws -> Response {
        // GET /api/appIcon?packageName=
        guard let packageName: String = req.query["packageName"] else {
            throw Abort(.badRequest)
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
            throw Abort(.badRequest)
        }
        let data = Data(buffer: buffer)
        try await req.application.iconProvider.saveIcon(data, for: packageName.lowercased())
        return .init(code: 200, isSuccess: true, message: "Added/updated new app icon.")
    }
}
