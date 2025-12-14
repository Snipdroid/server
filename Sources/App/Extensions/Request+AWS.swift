import SotoS3
import Vapor

extension Request {
    public var aws: AWS {
        .init(request: self)
    }

    public struct AWS {
        var client: AWSClient {
            return request.application.aws.client
        }

        let request: Request
    }
}

extension Request.AWS {
    public var s3: S3 {
        return request.application.aws.s3
    }

    // Not used
    public var s3Bucket: String {
        return request.application.aws.s3Bucket
    }
}
