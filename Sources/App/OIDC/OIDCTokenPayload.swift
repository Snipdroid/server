import JWT
import Vapor

struct OIDCTokenPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case issuer = "iss"
        case audience = "aud"
        case expiration = "exp"
        case issuedAt = "iat"
        case email
        case name
        case preferredUsername = "preferred_username"
    }

    var subject: SubjectClaim
    var issuer: IssuerClaim
    var audience: AudienceClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim?
    var email: String?
    var name: String?
    var preferredUsername: String?

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}
