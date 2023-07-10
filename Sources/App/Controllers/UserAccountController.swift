//
//  UserAccountController.swift
//  
//
//  Created by Butanediol on 2023/1/5.
//

import Vapor

struct UserAccountController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("api", "users")
        users.post(use: createUser)
        
        users.group(
                UserAccount.sessionAuthenticator(),
                UserToken.authenticator(),
                UserAccount.authenticator()
        ) {
            $0.post("login", use: userLogin)
            $0.get("iconpack", use: getUserIconPacks)
        }
        
    }
    
    func createUser(_ req: Request) async throws -> UserToken {
        try UserAccount.Create.validate(content: req)
        let create = try req.content.decode(UserAccount.Create.self)
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords did not match.")
        }
        
        let user = try UserAccount(
            name: create.name,
            email: create.email,
            passwordHash: Bcrypt.hash(create.password)
        )
        
        try await user.save(on: req.db)
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
        
    }
    
    func userLogin(_ req: Request) async throws -> UserToken {
        let user = try req.auth.require(UserAccount.self)
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    func getUserIconPacks(_ req: Request) async throws -> [IconPack] {
        let user = try req.auth.require(UserAccount.self)
        try await user.$iconPacks.load(on: req.db)
        return user.iconPacks
    }
}
