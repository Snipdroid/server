import JWT
import Vapor

struct OIDCDiscoveryDocument: Content {
    let issuer: String
    let jwksUri: String

    enum CodingKeys: String, CodingKey {
        case issuer
        case jwksUri = "jwks_uri"
    }
}

struct OIDCConfig: Sendable {
    let issuer: String
    let jwksURL: String
    let audience: String
}

extension Application {
    struct OIDCConfigKey: StorageKey {
        typealias Value = OIDCConfig
    }

    var oidc: OIDCConfig {
        get {
            guard let config = self.storage[OIDCConfigKey.self] else {
                fatalError("OIDC not configured. Call app.configureOIDC() first.")
            }
            return config
        }
        set {
            self.storage[OIDCConfigKey.self] = newValue
        }
    }

    func configureOIDC(issuer: String, audience: String) async throws {
        // Fetch discovery document
        let discoveryURL = "\(issuer)/.well-known/openid-configuration"
        let response = try await self.client.get(URI(string: discoveryURL))
        guard response.status == .ok else {
            throw Abort(.internalServerError, reason: "Failed to fetch OIDC discovery from \(discoveryURL): \(response.status)")
        }
        let discovery = try response.content.decode(OIDCDiscoveryDocument.self)

        // Verify issuer matches
        guard discovery.issuer == issuer else {
            throw Abort(.internalServerError, reason: "OIDC issuer mismatch: expected \(issuer), got \(discovery.issuer)")
        }

        // Fetch and load JWKS
        let jwksResponse = try await self.client.get(URI(string: discovery.jwksUri))
        guard jwksResponse.status == .ok else {
            throw Abort(.internalServerError, reason: "Failed to fetch JWKS from \(discovery.jwksUri): \(jwksResponse.status)")
        }
        let jwks = try jwksResponse.content.decode(JWKS.self)
        try await self.jwt.keys.add(jwks: jwks)

        // Store config
        self.oidc = OIDCConfig(issuer: issuer, jwksURL: discovery.jwksUri, audience: audience)
    }
}
