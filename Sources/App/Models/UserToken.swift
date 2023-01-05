//
//  UserToken.swift
//  
//
//  Created by Butanediol on 2023/1/5.
//

import Fluent
import Vapor

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

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user
    
    var isValid: Bool {
        expireAt != nil ? expireAt! > Date() : true
    }
}
