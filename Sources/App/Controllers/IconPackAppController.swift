import Fluent
import Vapor
import VaporToOpenAPI

struct IconPackAppController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        routes
            .get(
                "icon-pack-app", "drawable-name-suggestions",
                use: getDrawableNameSuggestions
            )
            .openAPI(
                summary: "Get drawable name suggestions by package name",
                description: "Get drawable name suggestions for an app by package name",
                query: .type(IconPackAppDrawableNameSuggestionRequest.self),
                response: .type([DrawableNameSuggestionResponse].self)
            )
    }

    @Sendable
    func getDrawableNameSuggestions(req: Request) async throws
        -> [DrawableNameSuggestionResponse]
    {
        let request = try req.query.decode(IconPackAppDrawableNameSuggestionRequest.self)

        return try await IconPackApp.query(on: req.db)
            .join(
                AppInfo.self,
                on: \IconPackApp.$appInfo.$id == \AppInfo.$id
                    && \AppInfo.$packageName == request.packageName
            )
            .join(IconPack.self, on: \IconPackApp.$iconPack.$id == \IconPack.$id)
            .all()
            .map {
                let iconPack = try $0.joined(IconPack.self)
                let iconPackID = try iconPack.requireID()
                let designerID = iconPack.$designer.id

                return DrawableNameSuggestionResponse(
                    drawable: $0.drawable,
                    from: iconPackID == request.iconPackID ? .iconPack :
                        designerID == request.designerID ? .designer : .none
                )
            }
    }
}
