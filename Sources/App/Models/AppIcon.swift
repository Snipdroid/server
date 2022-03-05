import Vapor
import Fluent

final class Icon: Model, Content {
    static var schema: String = "icon"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "package_name")
    var packageName: String

    @Field(key: "image")
    var image: Data

    init() {}

    init(packageName: String, image: Data) {
        self.packageName = packageName
        self.image = image
    }
}