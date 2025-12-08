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

        // Validate audience
        guard payload.audience.value.contains(oidcConfig.audience) else {
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
            // Update profile info from token if available
            var needsUpdate = false
            if let email = payload.email, existingDesigner.email != email {
                existingDesigner.email = email
                needsUpdate = true
            }
            if let name = payload.name ?? payload.preferredUsername, existingDesigner.name != name {
                existingDesigner.name = name
                needsUpdate = true
            }
            if needsUpdate {
                try await existingDesigner.save(on: request.db)
            }
            designer = existingDesigner
        } else {
            // Create new Designer (just-in-time provisioning)
            let newDesigner = Designer(
                oidcSubject: subject,
                oidcIssuer: issuer,
                email: payload.email,
                name: payload.name ?? payload.preferredUsername
            )
            try await newDesigner.save(on: request.db)
            designer = newDesigner
        }

        request.auth.login(designer)
    }
}
