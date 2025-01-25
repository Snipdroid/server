import Vapor

extension Designer {
    struct Register: Content {
        let uuid: UUID?
        let email: String
        let name: String
        let password: String
    }

    convenience init(register: Register) throws {
        self.init(
            id: register.uuid,
            name: register.name,
            email: register.email,
            passwordHash: try Bcrypt.hash(register.password)
        )
    }
}

extension Designer.Register: Validatable {
    static func validations(_ validations: inout Vapor.Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("name", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(8...))
    }
}
