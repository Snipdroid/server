import Vapor

enum InternalError<T>: Error {
    case decodingError(_ type: T.Type)
    case failedToAcquireID(_ model: T.Type)
    case failedToAcquireEntity(_ entity: T.Type)
    case violationOfUniqueConstraint(_ entity: T.Type)
    case invalidUrl(_ type: T.Type, _ url: String? = nil)
}

extension InternalError: AbortError {
    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .decodingError, .violationOfUniqueConstraint:
            return .badRequest
        case .failedToAcquireID, .failedToAcquireEntity, .invalidUrl:
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
        case .violationOfUniqueConstraint(let entity):
            return "Violation of unique constraint for \(entity)"
        case  .invalidUrl(let type, let url):
            return "Invalid \(type): \(url ?? "nil")"
        }
    }
}