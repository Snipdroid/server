import SwiftOpenAPI
import Vapor

@OpenAPIDescriptable
struct AppIconRequest: Content {
	/// The package name of the app.
	let packageName: String
}
