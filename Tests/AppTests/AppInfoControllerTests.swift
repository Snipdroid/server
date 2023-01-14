@testable import App
import XCTVapor

import Fluent

final class AppTests: XCTestCase {
        
    private var testApp: AppInfo!
    private var server: Application!
    private let appinfoEndpoint = "/api/appinfo"
    private let iconpackEndpoint = "/api/iconpack"

    override func setUp() async throws {
        try await super.setUp()
        self.testApp = AppInfo(
            id: UUID(),
            appName: Date().ISO8601Format(),
            packageName: [UInt8].random(count: 8).base64,
            activityName: [UInt8].random(count: 8).base64
        )
        self.server = Application(.testing)
        try await configure(self.server)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        server.shutdown()
    }
    
    func testAppInfoController() throws {
        var returnedApp: AppInfo!
        /// Add a new app
        try server.test(.POST, appinfoEndpoint, beforeRequest: { request in
            try request.content.encode(self.testApp)
        }, afterResponse: { response in
            returnedApp = try response.content.decode(AppInfo.self)
            XCTAssertEqual(returnedApp.appName, self.testApp.appName)
            XCTAssertEqual(returnedApp.packageName, self.testApp.packageName)
            XCTAssertEqual(returnedApp.activityName, self.testApp.activityName)
        })
        
        /// Search the new app
        try searchByName(returnedApp)
        try searchByPackage(returnedApp)
        try searchByName(returnedApp)
        try searchByRegex(returnedApp)
        
        /// Modify the app name
        try server.test(.PATCH, appinfoEndpoint, beforeRequest: { request in
            returnedApp.appName = Date().ISO8601Format()
            try request.content.encode([returnedApp])
        }, afterResponse: { response in
            let result = try response.content.decode(RequestResult.self)
            XCTAssertEqual(result.message, "Successfully updated 1 apps' name.")
        })
        
        /// Search the new app again
        try searchByName(returnedApp)
        try searchByPackage(returnedApp)
        try searchByName(returnedApp)
        try searchByRegex(returnedApp)

        /// Delete the new app
        try server.test(.DELETE, appinfoEndpoint) { request in
            let id = try returnedApp.requireID()
            try request.content.encode([id])
        } afterResponse: { response in
            let result = try response.content.decode(RequestResult.self)
            XCTAssertEqual(result.message, "Deleted 1 app(s), 0 request(s).")
        }

    }
    
    func searchByName(_ app: AppInfo) throws {
        try server.test(.GET, appinfoEndpoint, beforeRequest: { request in
            try request.query.encode([
                "q": app.appName
            ])
        }, afterResponse: { response in
            let decoded = try response.content.decode(Page<AppInfo>.self)
            XCTAssert(decoded.items.contains(app))
        })
    }
    
    func searchByPackage(_ app: AppInfo) throws {
        try server.test(.GET, appinfoEndpoint, beforeRequest: { request in
            try request.query.encode([
                "q": app.activityName
            ])
        }, afterResponse: { response in
            let decoded = try response.content.decode(Page<AppInfo>.self)
            XCTAssert(decoded.items.contains(app))
        })
    }
    
    func searchByActivity(_ app: AppInfo) throws {
        try server.test(.GET, appinfoEndpoint, beforeRequest: { request in
            try request.query.encode([
                "q": app.packageName
            ])
        }, afterResponse: { response in
            let decoded = try response.content.decode(Page<AppInfo>.self)
            XCTAssert(decoded.items.contains(app))
        })
    }
    
    func searchByRegex(_ app: AppInfo) throws {
        try server.test(.GET, appinfoEndpoint, beforeRequest: { request in
            try request.query.encode([
                "regex": "^\(app.appName)$"
            ])
        }, afterResponse: { response in
            let decoded = try response.content.decode(Page<AppInfo>.self)
            XCTAssert(decoded.items.contains(app))
        })
    }
    
    func testIconPackController() throws {
        let create = IconPack.Create(name: "test iconpack")
        try server.test(.POST, iconpackEndpoint + "/new") { request in
            try request.content.encode(create)
        } afterResponse: { response in
            let iconpack = try response.content.decode(IconPack.self)
            XCTAssertEqual(iconpack.name, create.name)
        }

    }
}

extension UUID: Content { }
