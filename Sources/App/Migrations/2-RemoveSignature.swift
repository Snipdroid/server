import Fluent
import Vapor

struct RemoveSignature: AsyncMigration {
    func prepare(on database: Database) async throws {

        let appInfoList = try await AppInfo.query(on: database).all()
        for index in appInfoList.indices {
            if appInfoList[index...].filter({ $0 == appInfoList[index] }).count > 1 {
                try await appInfoList[index].delete(on: database)
            }
            if ((index % 1000) == 0) {
                print("\(index) / \(appInfoList.count)")
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
