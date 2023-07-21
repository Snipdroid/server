import Fluent
import Vapor

func routes(_ app: Application) throws {
//    app.get { req async throws -> Response in
//        req.redirect(to: "/index.html")
//    }

    try app.register(collection: AppInfoController())
    try app.register(collection: IconController())
    try app.register(collection: IconPackController())
    try app.register(collection: TagController())
    try app.register(collection: UserAccountController())

    #if DEBUG
    app.routes.get("shutdown") { request -> Bool in
        app.shutdown()
        return true
    }
    #endif

    app.webSocket("api", "logstream") { req, ws async in
        ws.onText { ws, text async in
            if text == "close" { try? await ws.close() }
        }

        while !ws.isClosed {
            if let newLog = req.application.logPipe.newLog() {
                try? await ws.send(newLog.description)
            } else {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}