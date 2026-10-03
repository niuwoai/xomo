import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoAutomationRetouchWorkflowTests {
    @Test func blurSharpenPressureAutomationAcceptsSamplesAndSharesRetouchControls() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.setBrushPressureControlsSize(false)

        let blur = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("blur"),
                "pressureSize": .bool(true),
                "pressureSensitivity": .number(70),
                "points": .array([
                    .object([
                        "x": .number(24),
                        "y": .number(24),
                        "pressure": .number(0.2)
                    ])
                ])
            ]
        ))
        #expect(blur.ok)
        #expect(viewModel.retouchPressureControlsSize)
        #expect(viewModel.retouchPressureSensitivity == 70)
        #expect(!viewModel.brushPressureControlsSize)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.blur"))

        let sharpen = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sharpen"),
                "pressureSize": .bool(true),
                "points": .array([
                    .object([
                        "x": .number(24),
                        "y": .number(24),
                        "pressure": .number(1)
                    ])
                ])
            ]
        ))
        #expect(sharpen.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
    }

    @Test func registryAcceptsASinglePointSpongeDab() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sponge"),
                "spongeMode": .string("saturate"),
                "size": .number(12),
                "hardness": .number(1),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func registryAcceptsSinglePointBlurAndSharpenDabs() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let point: XomoJSONValue = .array([
            .object(["x": .number(32), "y": .number(32)])
        ])

        let blur = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("blur"),
                "size": .number(12),
                "hardness": .number(1),
                "points": point
            ]
        ))
        let sharpen = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sharpen"),
                "size": .number(12),
                "hardness": .number(1),
                "points": point
            ]
        ))

        #expect(blur.ok)
        #expect(sharpen.ok)
        #expect(viewModel.document.history.suffix(2).map(\.title) == [
            L10n.text("imageEditor.history.blur"),
            L10n.text("imageEditor.history.sharpen")
        ])
    }

    @Test func registryAcceptsSinglePointDodgeAndBurnDabs() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let point: XomoJSONValue = .array([
            .object(["x": .number(32), "y": .number(32)])
        ])

        let dodge = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "size": .number(12),
                "hardness": .number(1),
                "points": point
            ]
        ))
        let burn = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("burn"),
                "size": .number(12),
                "hardness": .number(1),
                "points": point
            ]
        ))

        #expect(dodge.ok)
        #expect(burn.ok)
        #expect(viewModel.document.history.suffix(2).map(\.title) == [
            L10n.text("imageEditor.history.dodge"),
            L10n.text("imageEditor.history.burn")
        ])
    }

    @Test func registryConfiguresAndValidatesDodgeBurnAirbrushPulses() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let point: XomoJSONValue = .array([
            .object(["x": .number(32), "y": .number(32)])
        ])
        #expect(!viewModel.toneBrushAirbrushEnabled)

        let enabled = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "airbrush": .bool(true),
                "airbrushPulses": .number(8),
                "points": point
            ]
        ))
        #expect(enabled.ok)
        #expect(viewModel.toneBrushAirbrushEnabled)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.dodge"))

        let disabled = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("burn"),
                "airbrush": .bool(false),
                "points": point
            ]
        ))
        #expect(disabled.ok)
        #expect(!viewModel.toneBrushAirbrushEnabled)

        let pulsesEnableAirbrush = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "airbrushPulses": .number(3),
                "points": point
            ]
        ))
        #expect(pulsesEnableAirbrush.ok)
        #expect(viewModel.toneBrushAirbrushEnabled)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("burn"),
                "airbrushPulses": .number(81),
                "points": point
            ]
        ))
        #expect(!invalid.ok)
        #expect(invalid.error?.contains("airbrushPulses") == true)
    }

    @Test func registryConfiguresBlurStrength() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("blur"),
                "strength": .number(0.28),
                "opacity": .number(0.91),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.opacity - 0.28) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.blur"))
    }

    @Test func registryConfiguresBurnExposure() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("burn"),
                "exposure": .number(0.46),
                "opacity": .number(0.89),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.opacity - 0.46) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @Test func registryConfiguresCurrentAndBelowPatchSampling() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 30))

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("patch"),
                "sampleSource": .string("currentAndBelow"),
                "points": .array([
                    .object(["x": .number(20), "y": .number(20)]),
                    .object(["x": .number(50), "y": .number(20)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.patchSampleSource == .currentAndBelow)
        #expect(!viewModel.patchSampleAllLayersEnabled)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPatch"))
    }

    @Test func registryConfiguresDodgeExposure() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "exposure": .number(0.34),
                "opacity": .number(0.87),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.opacity - 0.34) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
    }

    @Test func registryConfiguresSharpenStrength() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sharpen"),
                "strength": .number(0.42),
                "opacity": .number(0.93),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.opacity - 0.42) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
    }

    @Test func registryConfiguresSmudgeHardnessAndStrength() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("smudge"),
                "size": .number(12),
                "hardness": .number(0.24),
                "strength": .number(0.31),
                "opacity": .number(0.88),
                "points": .array([
                    .object(["x": .number(20), "y": .number(24)]),
                    .object(["x": .number(40), "y": .number(24)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.hardness - 0.24) < 0.001)
        #expect(abs(viewModel.opacity - 0.31) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @Test func registryConfiguresSpongeDesaturateMode() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sponge"),
                "spongeMode": .string("desaturate"),
                "size": .number(12),
                "hardness": .number(0.27),
                "points": .array([
                    .object(["x": .number(20), "y": .number(24)]),
                    .object(["x": .number(40), "y": .number(24)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.spongeMode == .desaturate)
        #expect(abs(viewModel.hardness - 0.27) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func registryKeepsLegacyDodgeOpacity() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "opacity": .number(0.43),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.opacity - 0.43) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
    }

    @Test func registryKeepsLegacySmudgeOpacity() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("smudge"),
                "opacity": .number(0.44),
                "points": .array([
                    .object(["x": .number(20), "y": .number(24)]),
                    .object(["x": .number(40), "y": .number(24)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(abs(viewModel.opacity - 0.44) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @Test func retouchPressureAutomationAcceptsToneAndSpongeSamplesAndAdvertisesControls() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.setBrushPressureControlsSize(false)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sponge"),
                "pressureSize": .bool(true),
                "pressureSensitivity": .number(75),
                "points": .array([
                    .object([
                        "x": .number(32),
                        "y": .number(32),
                        "pressure": .number(0.2)
                    ])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.retouchPressureControlsSize)
        #expect(viewModel.retouchPressureSensitivity == 75)
        #expect(!viewModel.brushPressureControlsSize)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))

        let dodgeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "pressureSize": .bool(true),
                "points": .array([
                    .object([
                        "x": .number(24),
                        "y": .number(24),
                        "pressure": .number(0.3)
                    ])
                ])
            ]
        ))
        #expect(dodgeResponse.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.dodge"))

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool array")
            return
        }
        let specialPaint = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.paint.special")
        })
        let schema = try #require(specialPaint["inputSchema"]?.objectValue)
        let properties = try #require(schema["properties"]?.objectValue)
        #expect(properties["pressureSize"]?.objectValue?["type"] == .string("boolean"))
        #expect(properties["pressureSensitivity"]?.objectValue?["type"] == .string("number"))
    }

    @Test func sampleAllLayersAutomationConfiguresSmudgeAndAdvertisesTheOption() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("smudge"),
                "sampleAllLayers": .bool(true),
                "points": .array([
                    .object(["x": .number(20), "y": .number(20)]),
                    .object(["x": .number(36), "y": .number(20)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.smudgeSampleAllLayersEnabled)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.smudge"))

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool array")
            return
        }
        let specialPaint = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.paint.special")
        })
        let schema = try #require(specialPaint["inputSchema"]?.objectValue)
        let properties = try #require(schema["properties"]?.objectValue)
        #expect(properties["sampleAllLayers"]?.objectValue?["type"] == .string("boolean"))
    }

    @Test func smudgePressureAutomationAcceptsSamplesAndSharesRetouchControls() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.setBrushPressureControlsSize(false)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("smudge"),
                "pressureSize": .bool(true),
                "pressureSensitivity": .number(65),
                "points": .array([
                    .object([
                        "x": .number(20),
                        "y": .number(20),
                        "pressure": .number(0.15)
                    ]),
                    .object([
                        "x": .number(40),
                        "y": .number(20),
                        "pressure": .number(1)
                    ])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.retouchPressureControlsSize)
        #expect(viewModel.retouchPressureSensitivity == 65)
        #expect(!viewModel.brushPressureControlsSize)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @Test func spongeVibranceAutomationConfiguresAndAdvertisesProtection() throws {
        let viewModel = try makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        #expect(viewModel.spongeVibranceEnabled)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sponge"),
                "spongeVibrance": .bool(false),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))
        #expect(response.ok)
        #expect(!viewModel.spongeVibranceEnabled)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool array")
            return
        }
        let specialPaint = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.paint.special")
        })
        let schema = try #require(specialPaint["inputSchema"]?.objectValue)
        let properties = try #require(schema["properties"]?.objectValue)
        #expect(properties["spongeVibrance"]?.objectValue?["type"] == .string("boolean"))
    }

    @Test(arguments: ["sponge", "dodge", "burn", "blur", "sharpen", "smudge", "patch"])
    func realRetouchChangesPixelsAndRoundTripsUndo(action: String) throws {
        let model = try makeViewModel()
        if action == "patch" {
            model.createRectSelection(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 30))
        }
        model.clearUndoHistory()
        let original = try #require(model.document.selectedLayer?.image.qingtuPNGData())
        let frame = try #require(model.document.selectedLayer?.frame)
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        let response = registry.execute(request(operation: "call", name: "xomo.paint.special",
            arguments: ["action": .string(action), "size": .number(12), "hardness": .number(1),
                "points": .array([
                    .object(["x": .number(20), "y": .number(20)]),
                    .object(["x": .number(50), "y": .number(20)])
                ])]))
        try #require(response.ok)
        let edited = try #require(model.document.selectedLayer?.image.qingtuPNGData())
        #expect(edited != original)
        #expect(model.undoStack.count == 1 && model.redoStack.isEmpty)
        model.undo()
        #expect(model.document.selectedLayer?.image.qingtuPNGData() == original)
        #expect(model.document.selectedLayer?.frame == frame)
        model.redo()
        #expect(model.document.selectedLayer?.image.qingtuPNGData() == edited)
    }

    @Test(arguments: ["sponge", "dodge", "burn", "blur", "sharpen", "smudge"])
    func transparentRetouchDoesNotInventAnUndoStep(action: String) throws {
        let model = ImageEditorViewModel(sourceName: "empty-retouch",
            image: .transparent(size: CGSize(width: 64, height: 64))) { _ in }
        model.clearUndoHistory()
        let original = try model.projectData()
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        let response = registry.execute(request(operation: "call", name: "xomo.paint.special",
            arguments: ["action": .string(action), "size": .number(12),
                "points": .array([.object(["x": .number(32), "y": .number(32)])])]))
        #expect(response.ok)
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
        #expect(try model.projectData() == original)
    }

    private func makeViewModel() throws -> ImageEditorViewModel {
        let width = 320
        let height = 240
        let size = CGSize(width: width, height: height)
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width,
            pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let pixels = try #require(bitmap.bitmapData)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bitmap.bytesPerRow + x * 4
                pixels[offset] = UInt8(80 + (x % 11) * 10)
                pixels[offset + 1] = UInt8(60 + (y % 9) * 14)
                pixels[offset + 2] = UInt8(90 + ((x + y) % 7) * 15)
                pixels[offset + 3] = 255
            }
        }
        bitmap.size = size
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        let model = ImageEditorViewModel(sourceName: "textured-retouch",
            image: .transparent(size: size)) { _ in }
        let index = try #require(model.document.selectedLayerIndex)
        model.document.layers[index].image = image
        model.clearUndoHistory()
        return model
    }

    private func request(operation: String, name: String? = nil,
        arguments: [String: XomoJSONValue]? = nil) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(token: "test-only", operation: operation,
            name: name, arguments: arguments)
    }
}
