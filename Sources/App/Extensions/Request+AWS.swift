import Vapor
import SotoS3

public extension Request {
    var aws: AWS {
        .init(request: self)
    }

    struct AWS {
        var client: AWSClient {
            return request.application.aws.client
        }

        let request: Request
    }
}

public extension Request.AWS {
    var s3: S3 {
        return request.application.aws.s3
    }

    var s3Bucket: String {
        return request.application.aws.s3Bucket
    }
}