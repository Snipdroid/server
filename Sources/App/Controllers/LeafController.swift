import Vapor
import VaporToOpenAPI

struct LeafController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes
            .post("render-leaf", use: renderLeaf)
            .openAPI(
                summary: "Render a template",
                description:
                    "Render a Leaf template, documentation is available at https://docs.vapor.codes/leaf/",
                body: .type(RenderRequest.self),
                response: .type(RenderResponse.self)
            )
    }

    @Sendable
    func renderLeaf(req: Request) async throws -> RenderResponse {
        let renderRequest = try req.content.decode(RenderRequest.self)
        let templateString = renderRequest.template
        let context = renderRequest.context

        let key = await LeafTemplateRepository.global.put(templateString)
        do {
            let data = try await req.view.render(key, context).get().data
            await LeafTemplateRepository.global.remove(key)
            return .init(text: String(buffer: data))
        } catch {
            throw Abort(
                .badRequest,
                reason: "Failed to render template, \(error.localizedDescription)"
            )
        }
    }
}
