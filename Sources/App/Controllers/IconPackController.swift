//
//  IconPackController.swift
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

        iconPack.group(IconPack.authenticator()) {
            $0.delete("appinfo", use: deleteRequests)
            $0.post("appinfo", use: createNewRequest)
        }
        
        iconPack.group(
            UserAccount.sessionAuthenticator(),
            UserToken.authenticator(),
            UserAccount.authenticator()
        ) {
            $0.post("new", use: newIconPack)
            $0.delete("delete", use: deleteIconPack)
        }
    }
    /*
     GET /api/iconpack/appinfo?iconpackid=
     Get all requests of an iconpack
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
            IconRequest.Created(id: $0.id, version: $0.version, count: $0.count, appInfo: AppInfo.Created($0.appInfo))
        }.paginate(for: req)
    }
    
    
    /*
     DELETE /api/iconpack/appinfo
     Delete requests
     */
    func deleteRequests(req: Request) async throws -> RequestResult {
        let uuidList = try req.content.decode([UUID].self)
        guard let iconPack = req.auth.get(IconPack.self) else {
            throw Abort(.unauthorized)
        }
        
        // Collect all requests to be deleted
        let deletionRequests = try await IconRequest.query(on: req.db)
            .filter(\.$id ~~ uuidList)
            .with(\.$fromIconPack)
            .filter(\.$fromIconPack.$id, .equal, iconPack.id!)
            .all()
        
        guard deletionRequests.count == deletionRequests.count else {
            throw Abort(.unauthorized, reason: "Token not eligible to delete all given requests.")
        }
        
        let deleteCount = deletionRequests.count
        try await deletionRequests.delete(on: req.db)
        
        return .init(code: 200, isSuccess: true, message: "Successfully deleted \(deleteCount) requests.")
    }

    /*
     POST /api/iconpack/appinfo
     Create request
     */
    func createNewRequest(req: Request) async throws -> [IconRequest] {
        guard let iconPack = req.auth.get(IconPack.self) else {
            throw Abort(.unauthorized)
        }

        return try await req.content.decode([IconRequest.Create].self).asyncMap { newIconRequestCreation in
            // Check existence
            let preexistedRequests = try await IconRequest.query(on: req.db)
                .filter(\.$appInfo.$id == newIconRequestCreation.appInfo)
                .filter(\.$version == newIconRequestCreation.version)
                .filter(\.$fromIconPack.$id == (try iconPack.requireID()))
                .all()

            guard preexistedRequests.count <= 1 else {
                req.logger.warning("More than 1 duplicated icon requests.")
                throw Abort(.internalServerError)
            }

            if let preexistedRequest = preexistedRequests.first {
                preexistedRequest.count += 1
                try await preexistedRequest.update(on: req.db)
                return preexistedRequest
            } else {
                let newRequest = IconRequest(
                    id: UUID(), 
                    version: newIconRequestCreation.version, 
                    count: 1, 
                    from: try iconPack.requireID(), 
                    for: newIconRequestCreation.appInfo
                )
                try await newRequest.create(on: req.db)
                return newRequest
            }
        }
    }
    
    /*
     POST /api/iconpack/new
     Create a new iconpack
     */
    func newIconPack(req: Request) async throws -> IconPack {
        let create = try req.content.decode(IconPack.Create.self)

        guard let user = req.auth.get(UserAccount.self) else {
            throw Abort(.unauthorized)
        }
        
        let iconPack = IconPack(name: create.name, designer: try user.requireID(), accessToken: user.generateTokenValue())
        try await iconPack.save(on: req.db)
        return iconPack
    }
    
    /*
     DELETE /api/iconpack/delete
     Delete an iconpack
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
        
        guard try iconPack.designer.requireID() == user?.id else {
            throw Abort(.unauthorized)
        }
        
        try await iconPack.delete(on: req.db)
        
        return .init(code: 200, isSuccess: true, message: "Icon pack \(iconPack.name) deleted.")
    }
}
