@testable import App
import Vapor
import VaporTesting
import Testing

@Suite("Mustache renderer")
struct MustacheControllerTests {
    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try app.register(collection: MustacheController())
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("Renders JSON context with Mustache semantics")
    func renderMustache() async throws {
        let request = RenderRequest(
            template: """
                {{title}}:{{#items}}{{name}}=\
                {{#enabled}}on{{/enabled}}{{^enabled}}off{{/enabled}};\
                {{/items}}{{^missing}}missing{{/missing}}
                """,
            context: [
                "title": .string("<Apps>"),
                "items": .array([
                    .object(["name": .string("One"), "enabled": .bool(true)]),
                    .object(["name": .string("Two"), "enabled": .bool(false)])
                ]),
                "missing": .null
            ]
        )

        try await withApp { app in
            try await app.testing().test(
                .POST,
                "render-template",
                beforeRequest: { try $0.content.encode(request, as: .json) },
                afterResponse: { response async throws in
                    #expect(response.status == .ok)
                    let rendering = try response.content.decode(RenderResponse.self).text
                    #expect(rendering == "&lt;Apps&gt;:One=on;Two=off;missing")
                }
            )
        }
    }

    @Test("Rejects malformed Mustache templates")
    func rejectMalformedTemplate() async throws {
        let request = RenderRequest(
            template: "{{#items}}",
            context: ["items": .array([])]
        )

        try await withApp { app in
            try await app.testing().test(
                .POST,
                "render-template",
                beforeRequest: { try $0.content.encode(request, as: .json) },
                afterResponse: { response async in
                    #expect(response.status == .badRequest)
                }
            )
        }
    }
}
