import Fluent
import JWT
import Vapor

struct OIDCAuthenticator: AsyncBearerAuthenticator {
    typealias User = Designer

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        let oidcConfig = request.application.oidc

        // Verify the token using JWKS
        let payload = try await request.jwt.verify(as: OIDCTokenPayload.self)

        // Validate issuer
        guard payload.issuer.value == oidcConfig.issuer else {
            throw Abort(.unauthorized, reason: "Invalid token issuer")
        }

        // Validate audience (token must contain at least one of the configured audiences)
        guard oidcConfig.audiences.contains(where: { payload.audience.value.contains($0) }) else {
            throw Abort(.unauthorized, reason: "Invalid token audience")
        }

        // Look up or create Designer
        let subject = payload.subject.value
        let issuer = payload.issuer.value

        let designer: Designer
        if let existingDesigner = try await Designer.query(on: request.db)
            .filter(\.$oidcSubject == subject)
            .filter(\.$oidcIssuer == issuer)
            .first()
        {
            designer = existingDesigner
        } else {
            // Create new Designer (just-in-time provisioning)
            // Profile data (email, name) will be populated via /designer/me/sync
            let newDesigner = Designer(
                oidcSubject: subject,
                oidcIssuer: issuer
            )
            try await newDesigner.save(on: request.db)
            designer = newDesigner
        }

        request.auth.login(designer)
    }
}
