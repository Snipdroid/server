import Vapor

extension Designer {
    struct DTO: Content {
        var id: UUID?
        var oidcSubject: String
        var oidcIssuer: String
        var email: String?
        var name: String?
        var createdAt: Date?
        var updatedAt: Date?
    }

    func toDTO() -> DTO {
        .init(
            id: self.id,
            oidcSubject: self.oidcSubject,
            oidcIssuer: self.oidcIssuer,
            email: self.email,
            name: self.name,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
