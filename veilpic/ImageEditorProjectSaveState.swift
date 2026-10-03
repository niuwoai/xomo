import Foundation

struct ImageEditorProjectSaveState {
    private var data: Data?
    private var metadata: ImageEditorProjectSaveMetadata?
    private var contentCheckpoint: ImageEditorProjectContentCheckpoint?

    mutating func update(_ data: Data?, metadata: ImageEditorProjectSaveMetadata?,
                         contentCheckpoint: ImageEditorProjectContentCheckpoint?) {
        self.data = data
        self.metadata = data == nil ? nil : metadata
        self.contentCheckpoint = data == nil ? nil : contentCheckpoint
    }

    func matchesData(_ data: Data) -> Bool { self.data == data }

    func differsInMetadata(_ metadata: ImageEditorProjectSaveMetadata) -> Bool {
        guard let saved = self.metadata else { return false }
        return saved != metadata
    }

    func matchesContent(_ project: ImageEditorProjectDocument) throws -> Bool? {
        try contentCheckpoint?.matches(project)
    }
}

@MainActor
extension ImageEditorViewModel {
    func updateProjectSaveBaseline(_ data: Data?, metadata: ImageEditorProjectSaveMetadata? = nil,
                                   contentCheckpoint: ImageEditorProjectContentCheckpoint? = nil) {
        projectSaveState.update(data, metadata: metadata, contentCheckpoint: contentCheckpoint)
    }

    func projectDataMatchesSaveBaseline(_ data: Data) -> Bool {
        projectSaveState.matchesData(data)
    }

    func projectMetadataDiffersFromSaveBaseline(_ metadata: ImageEditorProjectSaveMetadata) -> Bool {
        projectSaveState.differsInMetadata(metadata)
    }
}
