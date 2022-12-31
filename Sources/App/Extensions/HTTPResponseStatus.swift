//
//  File.swift
//  
//
//  Created by Butanediol on 2022/12/31.
//

import Vapor

extension HTTPResponseStatus {
    static func decodingError<T>(_ type: T.Type) -> Self {
        .init(statusCode: 1000, reasonPhrase: "Failed to decode \(String(describing: type)).")
    }
    
    static func notEnoughArguments(_ argument: String) -> Self {
        .init(statusCode: 1001, reasonPhrase: "Missing argument \(argument).")
    }
    
    static func either(_ a: Self, _ b: Self) -> Self {
        .init(statusCode: 1002, reasonPhrase: "\(a.reasonPhrase) or \(b.reasonPhrase)")
    }
    
    static func contentError(_ thing: String) -> Self {
        .init(statusCode: 1003, reasonPhrase: "Failed to get content of \(thing).")
    }
    
    static func existanceError(_ thing: String) -> Self {
        .init(statusCode: 1004, reasonPhrase: "No existance of \(thing).")
    }
}
