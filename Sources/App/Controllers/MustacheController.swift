import Mustache
import Vapor
import VaporToOpenAPI

struct MustacheController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes
            .post("render-template", use: renderMustache)
            .openAPI(
                summary: "Render a template",
                description: """
                    Render a Mustache template. Documentation: https://mustache.github.io/mustache.5.html
                    """,
                body: .type(RenderRequest.self),
                response: .type(RenderResponse.self)
            )
    }

    @Sendable
    func renderMustache(req: Request) async throws -> RenderResponse {
        let renderRequest = try req.content.decode(RenderRequest.self)

        do {
            let template = try MustacheTemplate(string: renderRequest.template)
            let context = renderRequest.context.mapValues(\.mustacheValue)
            return .init(text: template.render(context))
        } catch {
            throw Abort(
                .badRequest,
                reason: "Failed to render Mustache template, \(error.localizedDescription)"
            )
        }
    }
}
