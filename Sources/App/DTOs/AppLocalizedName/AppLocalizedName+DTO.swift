import Vapor

extension AppLocalizedName {
    struct DTO: Content {
        var languageCode: String
        var name: String
        var isPrimary: Bool
    }

    func toDTO() -> DTO {
        .init(
            languageCode: self.languageCode,
            name: self.name,
            isPrimary: self.isPrimary
        )
    }
}
