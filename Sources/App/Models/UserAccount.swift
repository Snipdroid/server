//
//  UserAccount.swift
//  
//
//  Created by Butanediol on 2023/1/5.
//

import Fluent
import Vapor

final class UserAccount: Model, Content {
    static let schema: String = "user_accounts"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "last_changed_at", on: .update)
    var lastChangedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Children(for: \.$designer)
    var iconPacks: [IconPack]
    
    init() {}
    
    init(
        id: UUID? = nil,
        name: String,
        email: String,
        passwordHash: String,
        cratedAt: Date? = Date(),
        lastChangedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
        self.createdAt = createdAt
        self.lastChangedAt = lastChangedAt
        self.deletedAt = deletedAt
        self.iconPacks = []
    }
}

extension UserAccount {
    struct Create: Content {
        let name: String
        let email: String
        let password: String
        let confirmPassword: String
    }
}

extension UserAccount.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension UserAccount: ModelAuthenticatable {
    static var usernameKey = \UserAccount.$email
    static var passwordHashKey = \UserAccount.$passwordHash
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension UserAccount {
    func generateToken(validFor period: TimeInterval = 86400) throws -> UserToken {
        try .init(
            value: generateTokenValue(),
            userID: self.requireID(),
            expireAt: Date() + period
        )
    }
    
    func generateTokenValue() -> String {
        [UInt8].random(count: 16).base64
    }
}

extension UserAccount: ModelSessionAuthenticatable {}
