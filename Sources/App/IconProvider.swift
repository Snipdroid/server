import Foundation
import SotoS3
import Vapor
import NIOCore

protocol IconProviderProtocol {

	func getIcon(from packageName: String) async throws -> Data

	func saveIcon(_ iconData: Data, for packageName: String) async throws

}

class LocalFileIconProvider: IconProviderProtocol {

	let application: Application

	init(application: Application) {
		self.application = application
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

class S3IconProvider: IconProviderProtocol {

	let client: AWSClient
	let s3: S3
	let bucket: String

	init(bucket: String, accessKeyId: String, secretAccessKey: String, s3Region: Region? = nil, s3Endpoint: String? = nil) {
		self.client = AWSClient.init(
				credentialProvider: .static(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey), 
				httpClientProvider: .createNew
			)
		self.s3 = S3(client: self.client, region: s3Region, endpoint: s3Endpoint)
		self.bucket = bucket
	}

	func getIcon(from packageName: String) async throws -> Data {
		return try await getIcon(withFileName: "\(packageName).png")
	}

	private func getIcon(withFileName key: String) async throws -> Data {
		let request = S3.GetObjectRequest(bucket: bucket, key: key)
		let response = try await s3.getObject(request)
		guard let body = response.body, let data = body.asData() else {
			throw Errors.failedToGetResponseBody
		}

		return data
	}

	func saveIcon(_ iconData: Data, for packageName: String) async throws {
		try await saveIcon(iconData, withFileName: "\(packageName).png")
	}

	private func saveIcon(_ iconData: Data, withFileName key: String) async throws {
		let request = S3.PutObjectRequest(body: .data(iconData),bucket: bucket, key: key)
		let _ = try await s3.putObject(request)
	}

	func shutdown() {
		do {
			try client.syncShutdown()
		} catch {
			print(error.localizedDescription)
		}
	}

	enum Errors: LocalizedError {
		case failedToGetResponseBody

		var errorDescription: String? {
			switch self {
				case .failedToGetResponseBody: return "Failed to get response body."
			}
		}
	}

}

struct IconProviderConfigurationKey: StorageKey {
	typealias Value = IconProviderProtocol
}

extension Application {
	var iconProvider: IconProviderProtocol {
		get {
			self.storage[IconProviderConfigurationKey.self] ?? LocalFileIconProvider(application: self)
		}
		set {
			self.storage[IconProviderConfigurationKey.self] = newValue
		}
	}
}

struct S3LifecycleHandler: LifecycleHandler {
	func shutdown(_ application: Application) {
		(application.iconProvider as! S3IconProvider).shutdown()
	}
}