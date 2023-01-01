//
//  File.swift
//  
//
//  Created by Butanediol on 2023/1/1.
//

import Vapor
import Fluent

struct TagController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let tag = routes.grouped("api", "tag")
        
        tag.get(use: getTag)
        tag.post(use: addTag)
        tag.post("appInfo", use: addTagToAppInfo)
    }
    
    func getTag(req: Request) async throws -> Tag {
        guard let tagName: String = req.query["tag"] else {
            throw(Abort(.notEnoughArguments("tag")))
        }
        
        guard let tag = try await Tag.query(on: req.db).filter(\.$name, .equal, tagName).with(\.$appInfos).first() else {
            throw(Abort(.existanceError("tag \(tagName)")))
        }
        
        return tag
    }

    func addTag(req: Request) async throws -> Tag {
        let newTag = try req.content.decode(Tag.self)
        try await newTag.save(on: req.db)
        return newTag
    }
    
    func addTagToAppInfo(req: Request) async throws -> AppInfoTagPivot {
        guard let addTagRequest = try? req.content.decode(TaggingRequest.self) else {
            throw Abort(.decodingError(TaggingRequest.self))
        }
        
        guard let appInfo = try await AppInfo.query(on: req.db).filter(\.$id, .equal, addTagRequest.appInfoId).first() else {
            throw Abort(.existanceError("appInfo, id: \(addTagRequest.appInfoId)"))
        }
        
        guard let tag = try await Tag.query(on: req.db).filter(\.$id, .equal, addTagRequest.tagId).first() else {
            throw Abort(.existanceError("tag, id: \(addTagRequest.tagId)"))
        }
        
        let newAppInfoTag = try AppInfoTagPivot(appInfo: appInfo, tag: tag)
        try await newAppInfoTag.save(on: req.db)
        try await newAppInfoTag.$appInfo.load(on: req.db)
        try await newAppInfoTag.$tag.load(on: req.db)
        return newAppInfoTag
    }
    
}
