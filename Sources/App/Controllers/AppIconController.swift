import Fluent
import PostgresKit
import SotoS3
import Vapor
import VaporToOpenAPI

struct AppIconController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appIcon = routes.grouped("app-icon")

        appIcon
            .get(use: redirect)
            .openAPI (
                summary: "Get app icon",
            )
            .response(
                statusCode: 307,
                headers: ["Location": .init(schemaObject: .uri)],
                description: "Redirect",
            )

        appIcon
            .get("generate-upload-url", use: generateUploadURL)
            .openAPI (
                summary: "Generate upload URL",
                query: .type(UploadRequest.self),
                response: .type(String.self)
            )
            .response(
                statusCode: 200,
                description: "Upload URL",
            )

    }

    @Sendable
    func redirect(req: Request) async throws -> Response {
        let packageName = try req.query.get(String.self, at: "packageName")

        let iconURL = try getIconURL(req: req, packageName: packageName)

        let signedURL = try await req.aws.s3.signURL(
            url: iconURL, httpMethod: .GET, expires: .minutes(60))

        let redirectResponse = req.redirect(to: signedURL.absoluteString, redirectType: .temporary)
        redirectResponse.headers.add(name: .cacheControl, value: "public, max-age=3600")
        return redirectResponse
    }

    fileprivate struct UploadRequest: Content {
        let packageName: String
    }

    @Sendable
    func generateUploadURL(req: Request) async throws -> String {

        let uploadRequest = try req.query.decode(UploadRequest.self)

        // 1. Check if the app exists
        guard
            (try await AppInfo.query(on: req.db)
                .filter(\.$packageName == uploadRequest.packageName)
                .first()) != nil
        else {
            throw Abort(.notFound)
        }

        // 2. Get the icon URL
        let iconURL = try getIconURL(req: req, packageName: uploadRequest.packageName)

        // 3. Sign the URL
        let signedURL = try await req.aws.s3.signURL(
            url: iconURL, httpMethod: .PUT, expires: .minutes(1))

        return signedURL.absoluteString
    }

    private func getIconURL(req: Request, packageName: String) throws -> URL {
        guard var components = URLComponents(string: req.aws.s3.endpoint),
            let host = components.host
        else {
            throw InternalError.invalidUrl(URLComponents.self, req.aws.s3.endpoint)
        }
        components.host = "\(req.aws.s3Bucket).\(host)"
        components.path = "/apptracker/\(packageName).png"

        guard let componentsURL = components.url else {
            throw InternalError.invalidUrl(URLComponents.self)
        }

        return componentsURL
    }

}
