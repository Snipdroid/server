import Vapor

extension IconPackVersion {
    struct DTO: Content {
        var id: UUID?
        var iconPackId: UUID
        var versionString: String
        var createdAt: Date?
        var token: String?
    }

    func toDTO(token: String?) -> DTO {
        .init(id: self.id, iconPackId: self.$iconPack.id, versionString: self.versionString, createdAt: self.createdAt, token: token)
    }
}