//
//  File.swift
//  
//
//  Created by Butanediol on 2022/12/31.
//

import Fluent
import FluentSQL
import Vapor

struct IconPackController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let iconPack = routes.grouped("api", ":iconpack")
        
        iconPack.get("appInfo", use: getAppInfo)
    }
    
    func getAppInfo(req: Request) async throws -> Page<AppInfoDTO> {
        guard let iconPackName: String = req.parameters.get("iconpack") else {
            throw Abort(.init(statusCode: 400, reasonPhrase: "Bad request. Invalid icon pack name."))
        }
        guard let iconPack = try await IconPack.query(on: req.db).filter(\.$name == iconPackName).first() else {
            throw Abort(.init(statusCode: 404, reasonPhrase: "Icon pack \(iconPackName) does not exist."))
        }

        let requests = try await iconPack.$requests.query(on: req.db).with(\.$appInfo).all()
        return try requests.paginate(for: req).map {
            AppInfoDTO(
                appName: $0.appInfo.appName,
                packageName: $0.appInfo.packageName,
                activityName: $0.appInfo.activityName,
                iconPack: nil,
                count: $0.count
            )
        }
    }
}
