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

struct CreateUserAccount: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_accounts")
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .date)
            .field("last_changed_at", .date)
            .field("deleted_at", .date)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user_accounts").delete()
    }
}

final class UserToken: Model, Content {
    static let schema = "user_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "value")
    var value: String

    @Parent(key: "user_id")
    var user: UserAccount
    
    @Timestamp(key: "expire_at", on: .none)
    var expireAt: Date?
    
    init() { }

    init(
        id: UUID? = nil,
        value: String,
        userID: UserAccount.IDValue,
        expireAt: Date? = nil
    ) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expireAt = expireAt
    }
}

struct CreateUserToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_tokens")
            .id()
            .field("value", .string, .required)
            .field("user_id", .uuid, .required, .references("user_accounts", "id"))
            .field("expire_at", .date)
            .unique(on: "value")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user_tokens").delete()
    }
}

extension UserAccount {
    func generateToken(validFor period: TimeInterval = 86400) throws -> UserToken {
        try .init(
            value: [UInt8].random(count: 16).base64,
            userID: self.requireID(),
            expireAt: Date() + period
        )
    }
}

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user
    
    var isValid: Bool {
        expireAt != nil ? expireAt! > Date() : true
    }
}

extension UserAccount: ModelSessionAuthenticatable {}
