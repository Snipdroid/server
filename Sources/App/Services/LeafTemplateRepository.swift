import Foundation

actor LeafTemplateRepository {
    private var templates: [String: String] = [:]

    func put(_ template: String) -> String {
        let key = UUID().uuidString
        templates[key] = template
        return key
    }

    func get(_ key: String) -> String? {
        return templates[key]
    }

    func remove(_ key: String) {
        templates.removeValue(forKey: key)
    }

    static let global = LeafTemplateRepository()
}
