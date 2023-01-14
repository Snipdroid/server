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
        let iconPack = routes.grouped("api", "iconpack")
        
        iconPack.get("appinfo", use: getRequests)
        iconPack.delete("appinfo", use: deleteRequests)
        
        let iconPackUserProtected = iconPack.grouped(
            UserAccount.sessionAuthenticator(),
            UserToken.authenticator(),
            UserAccount.authenticator()
        )
        
        iconPackUserProtected.post("new", use: newIconPack)
        iconPackUserProtected.delete("delete", use: deleteIconPack)
    }
    /*
     GET /api/iconpack/appinfo?iconpackid=
     */
    func getRequests(req: Request) async throws -> Page<IconRequest.Created> {
        guard let iconPackId: String = req.query["iconpackid"],
              let iconPackUuid = UUID(uuidString: iconPackId) else {
            throw Abort(
                .either(
                    .notEnoughArguments("iconpackid"),
                    .decodingError(UUID.self)
                )
            )
        }
        guard let iconPack = try await IconPack.query(on: req.db)
            .filter(\.$id == iconPackUuid)
            .first() else
        {
            throw Abort(.existenceError(iconPackId))
        }

        let requests = try await iconPack.$requests.query(on: req.db).with(\.$appInfo).all()
        return try requests.map {
            IconRequest.Created(id: $0.id, count: $0.count, appInfo: AppInfo.Created($0.appInfo))
        }.paginate(for: req)
    }
    
    
    /*
     DELETE /api/iconpack/appInfo
     Body: [IconRequest.id]
     */
    func deleteRequests(req: Request) async throws -> RequestResult {
        let uuidList = try req.content.decode([UUID].self)
        let token = req.headers.bearerAuthorization?.token
        
        let deletionRequests = try await IconRequest.query(on: req.db)
            .filter(\.$id ~~ uuidList)
            .with(\.$fromIconPack)
            .all()
            
        
        guard deletionRequests.filter({ $0.fromIconPack.accessToken == token }).count == deletionRequests.count else {
            throw Abort(.unauthorized, reason: "Token not eligible to delete all given requests.")
        }
        
        let deleteCount = deletionRequests.count
        try await deletionRequests.delete(on: req.db)
        
        return .init(code: 200, isSuccess: true, message: "Successfully deleted \(deleteCount) requests.")
    }
    
    /*
     POST /api/iconpack/new
     */
    func newIconPack(req: Request) async throws -> IconPack {
        let create = try req.content.decode(IconPack.Create.self)

        let user = req.auth.get(UserAccount.self)
        
        let iconPack = IconPack(name: create.name, designer: user?.id, accessToken: user?.generateTokenValue())
        try await iconPack.save(on: req.db)
        return iconPack
    }
    
    /*
     DELETE /api/iconpack/delete
     */
    func deleteIconPack(req: Request) async throws -> RequestResult {
        let delete = try req.content.decode(IconPack.Delete.self)

        let user = req.auth.get(UserAccount.self)
        
        guard let iconPack = try await IconPack.query(on: req.db)
            .with(\.$designer)
            .filter(\.$id, .equal, delete.id)
            .first()
        else {
            throw Abort(.existenceError("Icon Pack: \(delete.id.uuidString)"))
        }
        
        guard try iconPack.designer?.requireID() == user?.id else {
            throw Abort(.unauthorized)
        }
        
        try await iconPack.delete(on: req.db)
        
        return .init(code: 200, isSuccess: true, message: "Icon pack \(iconPack.name) deleted.")
    }
}
