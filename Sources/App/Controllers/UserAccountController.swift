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
        
        let userProtected = users
            .grouped(
                UserAccount.sessionAuthenticator(),
                UserToken.authenticator(),
                UserAccount.authenticator()
            )
        
        userProtected.post("login", use: userLogin)
        userProtected.get("me", use: getMe)
    }
    
    func createUser(_ req: Request) async throws -> UserAccount {
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
        return user
    }
    
    func userLogin(_ req: Request) async throws -> UserToken {
        let user = try req.auth.require(UserAccount.self)
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    func getMe(_ req: Request) async throws -> UserAccount {
        let user = try req.auth.require(UserAccount.self)
        try await user.$iconPacks.load(on: req.db)
        return user
    }
}
