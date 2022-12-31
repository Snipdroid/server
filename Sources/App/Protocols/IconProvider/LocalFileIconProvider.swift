import Vapor
import NIOCore

class LocalFileIconProvider: IconProviderProtocol {

	let application: Application

	init(application: Application) {
		self.application = application
	}

	func getIconUrl(packageName: String) async throws -> String {
		"/api/icon?packageName=\(packageName)"
	}

	private func getFile(from packageName: String) async throws -> (NIOFileHandle, FileRegion) {
		let file = try await application.fileio.openFile(
			path: "data/icons/\(packageName).png", 
			eventLoop: application.eventLoopGroup.next()
		).get()
		return file
	}

	func getIcon(from packageName: String) async throws -> Data {

		let file = try await getFile(from: packageName)
		
		let buffer = try await application.fileio.read(
			fileRegion: file.1, 
			allocator: .init(), 
			eventLoop: application.eventLoopGroup.next()
		).get()

		try file.0.close()

		return Data(buffer: buffer)
	}

	func saveIcon(_ iconData: Data, for packageName: String) async throws {

		let file = try await getFile(from: packageName)

		let buffer = ByteBuffer.init(data: iconData)

		try await application.fileio.write(
			fileHandle: file.0, 
			buffer: buffer, 
			eventLoop: application.eventLoopGroup.next()
		).get()

		try file.0.close()
	}
}