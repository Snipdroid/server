import Foundation
import JWT

extension Designer {
    struct Token: JWTPayload {

        enum CodingKeys: String, CodingKey {
            case expiration = "exp"

            case id
        }

        // JWT Claims

        var expiration: ExpirationClaim

        // Custom data

        var id: UUID

        func verify(using algorithm: some JWTKit.JWTAlgorithm) async throws {
            try self.expiration.verifyNotExpired()
        }
    }
}
