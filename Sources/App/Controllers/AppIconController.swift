import Fluent
import Vapor

struct AppIconController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appIcons = routes.grouped("api", "appIcon")

        appIcons.get(use: getIcon)
        // appIcons.post(use: newIcon)
        appIcons.on(.POST, body: .collect(maxSize: "1mb"), use: newIcon)
    }

    func getIcon(req: Request) async throws -> Response {
        // GET /api/appIcon?packageName=
        guard let packageName: String = req.query["packageName"] else {
            throw Abort(.badRequest)
        }

        guard let icon = try await Icon.query(on: req.db)
            .filter(\.$packageName == packageName)
            .first() else {
            throw Abort(.notFound)
        }
        
        let headers = HTTPHeaders()

        return .init(status: .ok, headers: headers, body: .init(data: icon.image))
    }

    func newIcon(req: Request) async throws -> RequestResult {
        // POST /api/appIcon?packageName=
        guard req.headers["Content-Type"].contains("image/jpeg") || req.headers["Content-Type"].contains("image/png"), 
            let packageName: String = req.query["packageName"],
            var buffer = req.body.data, 
            let data = buffer.readData(length: buffer.readableBytes) else {        
            throw Abort(.badRequest)
        }

        if let oldIcon = try await Icon.query(on: req.db).filter(\.$packageName == packageName).first() {
            oldIcon.image = data
            try await oldIcon.update(on: req.db)
            return .init(code: 200, isSuccess: true, message: "Updated app icon.")
        } else {
            let newIcon = Icon(packageName: packageName, image: data)
            try await newIcon.create(on: req.db)
            return .init(code: 200, isSuccess: true, message: "Added new app icon.")
        }
    }
}
