import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "Yes! It's up and running!"
    }

    app.group("api") { api in
        api.on(.GET, "search") { req -> EventLoopFuture<Page<AppInfo>> in
            guard let searchText: String = req.query["q"] else {
                throw Abort(.badRequest)
            }
            let searchTextMatrix = searchText.split(separator: " ").map { $0.split(separator: "+") }
            app.logger.info("Search app info '\(searchTextMatrix)'")

            return AppInfo.query(on: req.db)
                .filter(\.$signature == "")
                .group(.or) { group in
                    for col in searchTextMatrix {
                        group.group(.and) { subgroup in
                            for word in col {
                                subgroup.group(.or) { subsubgroup in
                                    subsubgroup
                                        .filter(\.$appName ~~ String(word))
                                        .filter(\.$packageName ~~ String(word))
                                        .filter(\.$activityName ~~ String(word))
                                }
                            }
                        }
                    }

                    // for searchText in searchTextList { // logic OR
                    //     group
                    //          .filter(\.$appName ~~ String(searchText))
                    //          .filter(\.$packageName ~~ String(searchText))
                    //          .filter(\.$activityName ~~ String(searchText))
                    // }

                    // logic AND
                    // group
                    //     .filter(\.$appName ~~ searchText)
                    //     .filter(\.$packageName ~~ searchText)
                    //     .filter(\.$activityName ~~ searchText)
                }
                .paginate(for: req)
        }

        api.on(.GET, "search", "regex") { req -> EventLoopFuture<Page<AppInfo>> in

            guard let pattern: String = req.query["q"], let regex = try? NSRegularExpression(pattern: pattern) else {
                throw Abort(.badRequest)
            }

            guard let page = try? req.query.decode(PageRequest.self) else {
                req.logger.error("Failed to decode page metadata")
                throw Abort(.badRequest)
            }

            return AppInfo.query(on: req.db)
                .all()
                .mapEachCompact { appInfo -> AppInfo? in
                    let doMatch = [appInfo.appName, appInfo.activityName, appInfo.packageName] // Fields to match
                        .map { field -> Bool in
                            let stringRange = NSRange(location: 0, length: field.utf16.count)
                            return regex.firstMatch(in: appInfo.appName, range: stringRange) != nil // check if current field matches
                        }
                        .contains(true) // check if any field matches
                    if doMatch { return appInfo } else { return nil} // if any does, return appInfo
                }
                .map { appInfoList -> Page<AppInfo> in
                    let total = appInfoList.count 
                    let per = page.per
                    let requestPage: Int = min(Int(ceil(Float(total) / Float(per))), page.page)
                    let left = per * (requestPage - 1)
                    let right = left + Int(min(per - 1, total - left - 1))
                    
                    return Page(
                        items: Array(appInfoList[left...right]), 
                        metadata: PageMetadata(
                            page: page.page, 
                            per: page.per, 
                            total: appInfoList.count
                        )
                    )
                }
        }

        api.on(.POST, "new") { req -> EventLoopFuture<AppInfo> in
            let newAppInfo = try req.content.decode(AppInfo.self)
            newAppInfo.id = UUID()
            newAppInfo.signature = newAppInfo.signature == "app-tracker" ? "" : newAppInfo.signature

            let sameAppInfo = AppInfo.query(on: req.db)
                .filter(\.$packageName == newAppInfo.packageName)
                .filter(\.$activityName == newAppInfo.activityName)

            // Update name
            let _ = sameAppInfo.all()
                .mapEach { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if oldAppInfo.appName == "" {
                        oldAppInfo.appName = newAppInfo.appName
                    } 
                    return oldAppInfo.update(on: req.db).map { oldAppInfo }
                }
            

            // look up existance -(T)> add in
            //                   -(F)> do nothing
            //                            ->    has signature  -(F)>    return
            //                                                 -(T)>    look up existance -(T)> count ++
            //                                                                            -(F)> add in

            // Erase signature and copy
            let signatureErased = sameAppInfo
                .filter(\.$signature == "")
                .first()
                .flatMap { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if let oldAppInfo = oldAppInfo {
                        // if exists, no nothing
                        // since the count does not matter
                        return oldAppInfo.update(on: req.db).map { oldAppInfo }
                    } else {
                        let signatureErasedAppInfo = newAppInfo
                        signatureErasedAppInfo.signature = "" // Erase signature
                        return signatureErasedAppInfo.create(on: req.db).map { signatureErasedAppInfo }
                    }
                }

            if newAppInfo.signature == "" {
                return sameAppInfo
                .filter(\.$signature == newAppInfo.signature)
                .first()
                .flatMap { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if let oldAppInfo = oldAppInfo {
                        // if exists, update count
                        oldAppInfo.count! += 1
                        return oldAppInfo.update(on: req.db).map { oldAppInfo }
                    } else {
                        // not exist
                        newAppInfo.count = 1
                        return newAppInfo
                            .create(on: req.db)
                            .map { newAppInfo }
                    }
                }
            } else {
                return signatureErased
            }
        }

        api.on(.DELETE, "remove") { req -> EventLoopFuture<String> in
            guard let id: UUID = req.query["id"] else {
                throw Abort(.badRequest)
            }

            return AppInfo.query(on: req.db)
                .filter(\.$id == id)
                .delete()
                .map { "Deleted row of ID \(id)" }
        }

        api.on(.DELETE, "remove", ":signature") { req -> EventLoopFuture<String> in
            guard let signature: String = req.parameters.get("signature") else {
                throw Abort(.badRequest)
            }

            let result = AppInfo.query(on: req.db).filter(\.$signature == signature)

            return result
                .count()
                .flatMap { count in
                    return result
                        .delete()
                        .map {
                            "Deleted all \(count) of signature \(signature)"
                        }
                }
        }

        api.on(.GET, "getExample") { req -> AppInfo in
            return AppInfo.getExample()
        }

        api.on(.GET, "getAll") { req -> EventLoopFuture<Page<AppInfo>> in 
            AppInfo.query(on: req.db)
                .unique()
                .paginate(for: req)
        }

        api.on(.GET, "getAll", ":signature") { req -> EventLoopFuture<Page<AppInfo>> in 

            guard let signature = req.parameters.get("signature") else { 
                // Never happens
                throw Abort(.badRequest)
            }

            return AppInfo.query(on: req.db)
                .filter(\.$signature == signature)
                .sort(\.$count, .descending)
                .paginate(for: req)
        }

        // api.on(.GET, "cleanup") { req -> EventLoopFuture<[AppInfo]> in
        //     return AppInfo.query(on: req.db)
        //         .all()
        //         .flatMapEachCompact(on: req.eventLoop) { appInfo -> EventLoopFuture<AppInfo?> in
        //             AppInfo.query(on: req.db)
        //                 .filter(\.$packageName == appInfo.packageName)
        //                 .filter(\.$activityName == appInfo.activityName)
        //                 .count()
        //                 .map { count in
        //                     if count > 1 {
        //                         return appInfo
        //                     } else {
        //                         return nil
        //                     }
        //                 }
        //         }                
        // }
    }
}
