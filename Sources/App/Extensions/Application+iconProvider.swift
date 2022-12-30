import Vapor

struct IconProviderConfigurationKey: StorageKey {
	typealias Value = IconProviderProtocol
}

extension Application {
	var iconProvider: IconProviderProtocol {
		get {
			self.storage[IconProviderConfigurationKey.self] ?? LocalFileIconProvider(application: self)
		}
		set {
			self.storage[IconProviderConfigurationKey.self] = newValue
		}
	}
}

struct S3LifecycleHandler: LifecycleHandler {
	func shutdown(_ application: Application) {
		(application.iconProvider as! S3IconProvider).shutdown()
	}
}