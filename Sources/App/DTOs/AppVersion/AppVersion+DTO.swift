import Vapor

extension AppVersion {
    struct DTO: Content {
        var id: UUID?
        var designerId: UUID
        var versionString: String
        var createdAt: Date?
        var token: String?
    }

    func toDTO(token: String?) -> DTO {
        .init(id: self.id, designerId: self.$designer.id, versionString: self.versionString, createdAt: self.createdAt, token: token)
    }
}