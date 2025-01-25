import Fluent
import Vapor

struct AppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfo = routes.grouped("app-info")

        appInfo.get(use: get)
        appInfo.post(use: create)
    }

    @Sendable
    func get(req: Request) async throws -> Page<AppInfo> {
        let query = try req.query.decode(AppInfo.Query.self)

        var queryBuilder: QueryBuilder<AppInfo> = AppInfo.query(on: req.db)
            .with(\.$localizedNames)

        if let byName = query.byName {
            queryBuilder =
                queryBuilder
                .join(AppLocalizedName.self, on: \AppInfo.$id == \AppLocalizedName.$appInfo.$id)
                .filter(AppLocalizedName.self, \.$name, .custom("ILIKE"), "%\(byName)%")
                .sort(.sql(embed: "similarity(\(idents: ["app_localized_names", "name"], joinedBy: "."), \(bind: byName)) DESC"))
        }

        if let byPackageName = query.byPackageName {
            queryBuilder = queryBuilder.filter(\.$packageName == byPackageName)
        }

        if let byMainActivity = query.byMainActivity {
            queryBuilder = queryBuilder.filter(\.$mainActivity == byMainActivity)
        }

        return try await queryBuilder.paginate(for: req)
    }

    @Sendable
    func create(req: Request) async throws -> AppInfo {
        let create = try req.content.decode(AppInfo.Create.self)

        // 1. Find or create an app info
        let appInfo = try await {
            if let existingAppInfo = try await AppInfo.query(on: req.db)
                .filter(\.$packageName == create.packageName)
                .filter(\.$mainActivity == create.mainActivity)
                .with(\.$localizedNames)
                .first()
            {
                return existingAppInfo
            } else {
                let newAppInfo = try AppInfo(create: create)
                try await newAppInfo.save(on: req.db)
                return newAppInfo
            }
        }()

        guard let appInfoId = try? appInfo.requireID() else {
            throw Abort(.failedToAcquireID)
        }

        // 2. Update or create a new localized name
        if let existingLocalizedName =
            try await AppLocalizedName
            .query(on: req.db)
            .filter(\.$appInfo.$id == appInfoId)
            .filter(\.$languageCode == create.languageCode)
            .first()
        {
            existingLocalizedName.name = create.localizedName
            try await existingLocalizedName.update(on: req.db)
        } else {
            let newLocalizedName = AppLocalizedName(
                appInfoId: appInfoId,
                languageCode: create.languageCode,
                name: create.localizedName,
                isPrimary: false
            )
            try await newLocalizedName.save(on: req.db)
        }

        // 3. Record the request
        let appVersionId = try? req.auth.require(AppVersion.self).requireID()
        let newRequestRecord = RequestRecord(appInfoId: appInfoId, appVersionId: appVersionId)
        try await newRequestRecord.save(on: req.db)

        return appInfo
    }
}
