import Vapor

extension IconPack {
    struct DTO: Content {
        var id: UUID?
        var designerId: UUID
        var name: String
        var createdAt: Date?
        var updatedAt: Date?
    }

    func toDTO() -> DTO {
        .init(
            id: self.id,
            designerId: self.$designer.id,
            name: self.name,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
