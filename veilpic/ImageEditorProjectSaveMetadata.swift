import AppKit
import Foundation

/// A dirty-only fast path, never evidence that a project is clean. Bitmap
/// objects remain mutable, so matching metadata still requires exact encoding.
struct ImageEditorProjectSaveMetadata: Equatable {
    let fields: Data
    let selection: ImageEditorSelection?
    let savedSelection: ImageEditorSelection?
    let alphaChannels: [ImageEditorAlphaChannel]
    let layerComps: [ImageEditorLayerComp]?

    init(project: ImageEditorProjectDocument) throws {
        selection = project.selection
        savedSelection = project.savedSelection
        alphaChannels = project.alphaChannels
        layerComps = project.layerComps
        var metadata = project
        // Compare large value-semantic masks directly instead of expanding
        // millions of alpha samples into JSON for each window-state update.
        metadata.selection = nil
        metadata.savedSelection = nil
        metadata.alphaChannels = []
        metadata.layerComps = nil
        for index in metadata.layers.indices {
            metadata.layers[index].imageData = nil
            metadata.layers[index].maskData = nil
            metadata.layers[index].xomoFigmaImageFillSourceImageData = nil
        }
        if var sources = metadata.smartObjectSources {
            for index in sources.indices { sources[index].imageData = Data() }
            metadata.smartObjectSources = sources
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        fields = try encoder.encode(metadata)
    }
}

extension ImageEditorProjectDocument {
    func encodedProjectData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

@MainActor
extension ImageEditorViewModel {
    func projectDocument(rasterEncoder: (NSImage) -> Data? = { $0.qingtuPNGData() }) throws -> ImageEditorProjectDocument {
        try ImageEditorProjectDocument(
            document: document,
            xomoComponentTheme: xomoComponentTheme,
            xomoLocalThemeTokenSnapshot: xomoLocalThemeTokenSnapshot,
            colorSamplerPoints: colorSamplerPoints,
            colorSamplerReadoutMode: selectedColorSamplerReadoutMode,
            colorSamplerSampleSize: selectedColorSamplerSampleSize,
            colorSamplerSource: selectedColorSamplerSource,
            colorSamplerIgnoresAdjustmentLayers: colorSamplerIgnoresAdjustmentLayers,
            rasterEncoder: rasterEncoder
        )
    }

    func projectHasUnsavedChanges(rasterEncoder: (NSImage) -> Data? = { $0.qingtuPNGData() }) -> Bool {
        if let project = try? projectDocument(rasterEncoder: { _ in Data() }),
           let metadata = try? ImageEditorProjectSaveMetadata(project: project),
           projectMetadataDiffersFromSaveBaseline(metadata) {
            return true
        }
        do {
            let project = try projectDocument(rasterEncoder: rasterEncoder)
            if let matches = try projectSaveState.matchesContent(project) {
                return !matches
            }
            return !projectDataMatchesSaveBaseline(try project.encodedProjectData())
        } catch {
            return true
        }
    }
}
