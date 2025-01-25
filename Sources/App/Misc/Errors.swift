import Vapor

enum InternalError<T>: Error {
    case decodingError(_ type: T.Type)
    case failedToAcquireID(_ model: T.Type)
    case failedToAcquireEntity(_ entity: T.Type)
}

extension InternalError: AbortError {
    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .decodingError:
            return .badRequest
        case .failedToAcquireID, .failedToAcquireEntity:
            return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .decodingError(let type):
            return "Failed to decode \(type)"
        case .failedToAcquireID(let model):
            return "Failed to acquire ID for \(model)"
        case .failedToAcquireEntity(let entity):
            return "Failed to acquire entity \(entity)"
        }
    }
}