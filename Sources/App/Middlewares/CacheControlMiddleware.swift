import Vapor

struct AsyncCacheControlMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        if let contentType = response.headers.contentType {
            switch (contentType.type, contentType.subType) {
            case ("text", "javascript"), ("text", "css"), ("image", _):
                response.headers.add(name: .cacheControl, value: "public, max-age=31536000")
                response.headers.remove(name: .eTag)
            case ("text", "html"):
                response.headers.add(name: .cacheControl, value: "no-cache")
            default:
                break
            }
        }
        return response
    }
}
