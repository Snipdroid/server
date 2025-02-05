import Fluent
import PostgresKit
import Vapor

struct AppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfo = routes.grouped("app-info")

        appInfo.get("search", use: search)
        appInfo.grouped(AppVersionAuthenticator()).post("create", use: create)
    }

    @Sendable
    func search(req: Request) async throws -> Page<AppInfo> {
        let query = try req.query.decode(AppInfo.Query.self)

        var queryBuilder: QueryBuilder<AppInfo> = AppInfo.query(on: req.db)
            .with(\.$localizedNames)

        if let byName = query.byName {
            let appInfoIds = try await AppLocalizedName.query(on: req.db)
                .filter(\.$name, .custom("ILIKE"), "%\(byName)%")
                .sort(
                    .sql(
                        embed:
                            "similarity(\(idents: ["app_localized_names", "name"], joinedBy: "."), \(bind: byName)) DESC"
                    )
                )
                .all()
                .uniqued(on: \.$appInfo.id)
                .map(\.$appInfo.id)

            queryBuilder = queryBuilder.filter(\.$id ~~ appInfoIds)
        }

        if let byPackageName = query.byPackageName {
            queryBuilder = queryBuilder.filter(\.$packageName == byPackageName)

        }

        if let byMainActivity = query.byMainActivity {
            queryBuilder = queryBuilder.filter(\.$mainActivity == byMainActivity)

        }

        return
            try await queryBuilder
            .sort(\.$count, .descending)
            .paginate(for: req)
    }

    @Sendable
    func create(req: Request) async throws -> [AppInfo] {
        let appVersionId = try? req.auth.require(AppVersion.self).requireID()
        let creates = try req.content.decode([AppInfo.Create].self)

        // 1. Batch query existing AppInfo
        let existingAppInfos = try await AppInfo.query(on: req.db)
            .group(.or) { or in
                creates.forEach { create in
                    or.group(.and) { and in
                        and.filter(\.$packageName == create.packageName)
                        and.filter(\.$mainActivity == create.mainActivity)
                    }
                }
            }
            .with(\.$localizedNames)
            .all()

        // 2. Create a quick lookup table for existing AppInfo by packageName and mainActivity
        struct AppInfoKey: Hashable {
            let packageName: String
            let mainActivity: String
        }
        let existingMap: [AppInfoKey: AppInfo] = existingAppInfos.reduce(into: [:]) {
            result, appInfo in
            result[
                AppInfoKey(packageName: appInfo.packageName, mainActivity: appInfo.mainActivity)] =
                appInfo
        }

        // 3. Create new AppInfos for non-existing entries
        let newAppInfos = creates.compactMap { create -> AppInfo? in
            let key = AppInfoKey(packageName: create.packageName, mainActivity: create.mainActivity)
            if existingMap[key] == nil {
                return AppInfo(create: create)
            }
            return nil
        }

        // 4. Batch save new AppInfos
        try await newAppInfos.create(on: req.db)

        // 5. Get all AppInfos (both existing and new)
        let allAppInfos = existingAppInfos + newAppInfos

        // 6. Batch query existing localized names
        let existingLocalizedNames = try await AppLocalizedName.query(on: req.db)
            .group(.or) { or in
                allAppInfos.forEach { appInfo in
                    if let appInfoId = try? appInfo.requireID() {
                        or.filter(\.$appInfo.$id == appInfoId)
                    } else {
                        req.logger.report(error: InternalError.failedToAcquireID(AppInfo.self))
                    }
                }
            }
            .all()

        // 7. Create lookup map for existing localized names
        struct LocalizedNameKey: Hashable {
            let appInfoId: UUID
            let languageCode: String
        }
        let existingLocalizedNamesMap: [LocalizedNameKey: AppLocalizedName] =
            existingLocalizedNames.reduce(into: [:]) { result, name in
                result[
                    LocalizedNameKey(appInfoId: name.$appInfo.id, languageCode: name.languageCode)] =
                    name
            }

        // 8. Prepare new localized names and updates
        var newLocalizedNames: [AppLocalizedName] = []
        var localizedNamesToUpdate: [AppLocalizedName] = []

        for (appInfo, create) in zip(allAppInfos, creates) {
            guard let appInfoId = try? appInfo.requireID() else {
                req.logger.report(error: InternalError.failedToAcquireID(AppInfo.self))
                continue
            }
            let key = LocalizedNameKey(appInfoId: appInfoId, languageCode: create.languageCode)

            if let existingName = existingLocalizedNamesMap[key] {
                existingName.name = create.localizedName
                localizedNamesToUpdate.append(existingName)
            } else {
                let newName = AppLocalizedName(
                    appInfoId: appInfoId,
                    languageCode: create.languageCode,
                    name: create.localizedName,
                    isPrimary: false
                )
                newLocalizedNames.append(newName)
            }
        }

        // 9. Batch create new localized names
        try await newLocalizedNames.create(on: req.db)

        // 10. Update existing localized names one by one
        for name in localizedNamesToUpdate {
            try await name.update(on: req.db)
        }

        // 11. Batch create request records
        let requestRecords = allAppInfos.compactMap { appInfo -> RequestRecord? in
            guard let appInfoId = try? appInfo.requireID() else {
                req.logger.report(error: InternalError.failedToAcquireID(AppInfo.self))
                return nil
            }
            return RequestRecord(appInfoId: appInfoId, appVersionId: appVersionId)
        }
        try await requestRecords.create(on: req.db)

        return allAppInfos
    }

    @Sendable
    func createSingle(req: Request) async throws -> AppInfo {
        let appVersionId = try? req.auth.require(AppVersion.self).requireID()
        guard let create = try req.content.decode([AppInfo.Create].self).first else {
            throw InternalError.decodingError([AppInfo.Create].self)
        }

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
                let newAppInfo = AppInfo(create: create)
                try await newAppInfo.save(on: req.db)
                return newAppInfo
            }
        }()

        guard let appInfoId = try? appInfo.requireID() else {
            throw InternalError.failedToAcquireID(AppInfo.self)
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
        let newRequestRecord = RequestRecord(appInfoId: appInfoId, appVersionId: appVersionId)
        try await newRequestRecord.save(on: req.db)

        return appInfo
    }
}
