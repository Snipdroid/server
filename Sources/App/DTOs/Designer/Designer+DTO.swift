import Vapor

extension Designer {
    struct DTO: Content {
        var id: UUID?
        var email: String
        var name: String
        var createdAt: Date?
        var token: String?
    }

    func toDTO(token: String?) -> DTO {
        .init(id: self.id, email: self.email, name: self.name, createdAt: self.createdAt, token: token)
    }
}