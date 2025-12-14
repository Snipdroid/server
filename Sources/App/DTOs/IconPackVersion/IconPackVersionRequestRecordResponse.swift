import SwiftOpenAPI
import Vapor

@OpenAPIDescriptable
struct IconPackVersionRequestRecordResponse: Content {
	let requestRecord: RequestRecordDTO

	/// nil if the requested app is not adapted
	let iconPackApp: IconPackAppDTO?
}
