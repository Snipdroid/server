import Vapor

struct BaseUrlKey: StorageKey {
    typealias Value = String
}

extension Application {
    var baseUrl: String! {
        get {
            self.storage[BaseUrlKey.self]
        }
        set {
            self.storage[BaseUrlKey.self] = newValue
        }
    }
}