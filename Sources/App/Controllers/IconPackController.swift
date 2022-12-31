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
        
        iconPack.get("appInfo", use: getRequests)
        iconPack.delete("appInfo", use: deleteRequests)
    }
    /*
     GET /api/:iconpack/appInfo
     */
    func getRequests(req: Request) async throws -> Page<IconRequestDTO> {
        guard let iconPackName: String = req.parameters.get("iconpack") else {
            throw Abort(.init(statusCode: 400, reasonPhrase: "Bad request. Invalid icon pack name."))
        }
        guard let iconPack = try await IconPack.query(on: req.db).filter(\.$name == iconPackName).first() else {
            throw Abort(.init(statusCode: 404, reasonPhrase: "Icon pack \(iconPackName) does not exist."))
        }

        let requests = try await iconPack.$requests.query(on: req.db).with(\.$appInfo).all()
        return try requests.paginate(for: req).map {
            IconRequestDTO(
                appInfoId: $0.appInfo.id,
                iconRequestId: $0.id,
                appName: $0.appInfo.appName,
                packageName: $0.appInfo.packageName,
                activityName: $0.appInfo.activityName,
                count: $0.count
            )
        }
    }
    
    
    /*
     DELETE /api/:iconpack/appInfo
     Body: [IconRequest.id]
     */
    func deleteRequests(req: Request) async throws -> RequestResult {
        let requestsToDelete = try req.content.decode([UUID].self)
        
        var deleteCount = 0
        
        try await requestsToDelete.asyncForEach { requestId in
            if let request = try await IconRequest.query(on: req.db).filter(\.$id, .equal, requestId).first() {
                try await request.delete(on: req.db)
                deleteCount += 1
            }
        }
        
        return .init(code: 200, isSuccess: true, message: "Successfully deleted \(deleteCount) requests.")
    }
}
