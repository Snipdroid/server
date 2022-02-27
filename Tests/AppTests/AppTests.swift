@testable import App
import XCTVapor

import Fluent

final class AppTests: XCTestCase {
    func testServer() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Yes! It's up and running!")
        }
    }

    func testSearch() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/api/search?q=app-tracker") { res in
            XCTAssertEqual(res.status, .ok)

            guard let data = res.body.string.data(using: .utf8) else { throw TestError.cannotConvertStringToData }
            let appInfoList = try JSONDecoder().decode(Page<AppInfo>.self, from: data)
            XCTAssertGreaterThan(appInfoList.items.count, 0)
        }
    }

    func testSearchRegex() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "/api/search/regex?q=%5E%5B0%2D9%5D%2B%24") { res in
            XCTAssertEqual(res.status, .ok)

            guard let data = res.body.string.data(using: .utf8) else { throw TestError.cannotConvertStringToData }
            let appInfoList = try JSONDecoder().decode(Page<AppInfo>.self, from: data)
            XCTAssertGreaterThan(appInfoList.items.count, 0)
        }
    }
}
