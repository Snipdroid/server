import Vapor

extension IconPack {
    struct AddCollaboratorsRequest: Content {
        let designerIds: [UUID]
    }
}
