import Foundation
import SotoS3
import Vapor

protocol IconProviderProtocol {

	func getIcon(from packageName: String) async throws -> Data

	func saveIcon(_ iconData: Data, for packageName: String) async throws

}