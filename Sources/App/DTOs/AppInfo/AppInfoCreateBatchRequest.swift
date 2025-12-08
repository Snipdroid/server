import SwiftOpenAPI
import Vapor

typealias AppInfoCreateBatchRequest = Set<AppInfoCreateSingleRequest>

@OpenAPIDescriptable
struct AppInfoCreateSingleRequest: Content, Hashable {
    /// The default display name of the app (used as fallback when no localized name matches)
    let defaultName: String

    /// The localized name of the app in the specified language
    let localizedName: String

    /// IETF language tag (e.g., "en", "zh-Hans", "ja")
    let languageCode: String

    /// Android package name (e.g., "com.google.android.apps.maps")
    let packageName: String

    /// Android main activity class name (e.g., "com.google.android.maps.MapsActivity")
    let mainActivity: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(packageName)
        hasher.combine(mainActivity)
    }
}

extension AppInfo {
    convenience init(create: AppInfoCreateSingleRequest) {
        self.init(
            id: UUID(), defaultName: create.defaultName, packageName: create.packageName,
            mainActivity: create.mainActivity)
    }
}
