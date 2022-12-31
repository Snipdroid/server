import Foundation
import SotoS3

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

	func getIconUrl(packageName: String) async throws -> String {
		guard let url = URL(string: s3.endpoint)?
			.appendingPathComponent(bucket)
			.appendingPathComponent(packageName)
			.appendingPathExtension("png") else {
				throw Errors.failedToGetResponseBody
			}
		let signedUrl = try await s3.signURL(url: url, httpMethod: .GET, expires: .minutes(5))
		return signedUrl.absoluteString
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
		case failedToGetIconUrl

		var errorDescription: String? {
			switch self {
				case .failedToGetResponseBody: return "Failed to get response body."
				case .failedToGetIconUrl: return "Failed to get icon url."
			}
		}
	}

}