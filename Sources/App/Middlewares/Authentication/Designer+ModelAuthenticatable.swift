import Vapor
import Fluent

extension Designer: ModelAuthenticatable {
    static let usernameKey = \Designer.$email
    static let passwordHashKey = \Designer.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}