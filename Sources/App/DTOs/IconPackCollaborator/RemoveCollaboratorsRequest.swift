import Vapor

extension IconPack {
    struct RemoveCollaboratorsRequest: Content {
        let designerIds: [UUID]
    }
}
