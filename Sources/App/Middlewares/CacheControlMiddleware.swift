import Vapor

struct CacheControlMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return next.respond(to: request).map { response in
            if request.method == .GET {
                response.headers.add(name: "access-control-max-age", value: "600")
                response.headers.add(name: "cache-control", value: "max-age=600")
            }
            return response
        }
    }
}