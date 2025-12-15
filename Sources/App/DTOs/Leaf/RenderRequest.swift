import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
struct RenderRequest: Codable, WithExample, Sendable {
    static let example = RenderRequest(
        template: """
            #for(f in foo):
            Item #(f)
            #endfor
            """,
        context: [
            "foo": .array([.number(1), .number(2)])
        ]
    )

    /// The template to render in Leaf format
    let template: String

    /// The context for the template
    let context: [String: JSONValue]
}
