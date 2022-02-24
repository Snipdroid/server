import Fluent
import Vapor

struct PlayApp: Content {
    var name: String
    var url: String
    var image: String

    static let placeholder = PlayApp(name: "Placeholder", url: "https://app-tracker.k2t3k.tk", image: "https://cloudreve.butanediol.me/api/v3/file/source/18/NB_Icon_Mask_Shapes_Ext_02.gif?sign=aZPSh9NjBJl_jpFPNKtbefksgEOJ_IHb2FpBiWpjBoA%3D%3A0")
}