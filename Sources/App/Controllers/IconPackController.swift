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
            throw Abort(.notEnoughArguments("iconpack"))
        }
        guard let iconPack = try await IconPack.query(on: req.db).filter(\.$name == iconPackName).first() else {
            throw Abort(.existanceError(iconPackName))
        }

        let requests = try await iconPack.$requests.query(on: req.db).with(\.$appInfo).all()
        return try requests.map {
            IconRequestDTO(iconRequestId: $0.id, count: $0.count, appInfo: AppInfoDTO($0.appInfo))
        }.paginate(for: req)
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
