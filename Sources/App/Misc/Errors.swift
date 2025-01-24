import NIOHTTP1

extension HTTPResponseStatus {
    static let failedToAcquireEntity = Self.custom(code: 0x401, reasonPhrase: "Failed to acquire ID.")
    static let failedToAcquireID = Self.custom(code: 0x402, reasonPhrase: "Failed to acquire entity.")
}
