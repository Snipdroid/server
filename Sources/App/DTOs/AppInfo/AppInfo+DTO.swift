import Vapor

extension AppInfo {
    struct DTO: Content {
        var id: UUID?
        var defaultName: String
        var localizedNames: [AppLocalizedName.DTO]
        var packageName: String
        var mainActivity: String
        var createdAt: Date?
        var count: Int
    }

    func toDTO() -> DTO {
        .init(
            id: self.id,
            defaultName: self.defaultName,
            localizedNames: self.localizedNames.map { $0.toDTO() },
            packageName: self.packageName,
            mainActivity: self.mainActivity,
            createdAt: self.createdAt,
            count: self.count
        )
    }
}
