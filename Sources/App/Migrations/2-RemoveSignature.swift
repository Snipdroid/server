import Fluent
import Vapor

private class AppInfoLegacy: Model {
    static func ~= (lhs: AppInfoLegacy, rhs: AppInfoLegacy) -> Bool {
        lhs.packageName == rhs.packageName &&
        lhs.activityName == rhs.activityName
    }
    
    static let schema = "app_infos"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "app_name")
    var appName: String

    @Field(key: "package_name")
    var packageName: String

    @Field(key: "activity_name")
    var activityName: String
    
    @Field(key: "count")
    var count: Int
    
    required init() { }
}

struct RemoveSignature: AsyncMigration {
    func prepare(on database: Database) async throws {

        let appInfoList = try await AppInfoLegacy.query(on: database).all()
        for index in appInfoList.indices {
            if appInfoList[index...].filter({ $0 ~= appInfoList[index] }).count > 1 {
                try await appInfoList[index].delete(on: database)
            }
            if ((index % 1000) == 0) {
                print("\r\(index) / \(appInfoList.count)")
            }
        }

        try await database.schema("app_infos")
            .deleteField("signature")
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("app_infos")
            .field("signature", .string, .required)
            .update()
    }
}
