import LeafKit
import NIO

struct DynamicLeafSource: LeafSource {
    private let templateRepository: LeafTemplateRepository

    func file(template: String, escape: Bool, on eventLoop: any EventLoop) throws
        -> EventLoopFuture<ByteBuffer>
    {
        let promise = eventLoop.makePromise(of: ByteBuffer.self)

        Task {
            if let tpl = await templateRepository.get(template) {
                promise.succeed(ByteBuffer(string: tpl))
            } else {
                promise.fail(LeafError(.noTemplateExists(template)))
            }
        }

        return promise.futureResult
    }

    static let global = DynamicLeafSource(templateRepository: .global)
}
