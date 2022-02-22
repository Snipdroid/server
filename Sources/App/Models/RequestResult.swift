import Vapor

struct RequestResult: Codable, Content {

    var code: Int
    var isSuccess: Bool
    var message: String
}