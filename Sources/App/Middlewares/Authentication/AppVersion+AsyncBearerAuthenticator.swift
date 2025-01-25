import Vapor

struct AppVersionAuthenticator: AsyncBearerAuthenticator {
    typealias User = AppVersion

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        let appVersionToken = try await request.jwt.verify(as: AppVersion.Token.self)
        guard let appVersion = try await AppVersion.find(appVersionToken.id, on: request.db) else {
            throw Abort(.unauthorized)
        }
        request.auth.login(appVersion)
   }
}

extension AppVersion: Authenticatable {}