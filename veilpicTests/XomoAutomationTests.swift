import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationTests {
    @Test func registryAdvertisesBroadEditorCapabilities() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(operation: "tools"))
        #expect(response.ok)
        guard case .array(let tools) = response.result else {
            Issue.record("Expected tool array")
            return
        }
        #expect(tools.count == 111)
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.layer.list")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.channel.action")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.path.action")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.clipboard.action")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.layer_comp.action")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.brush.preset")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.text.convert")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.text.fitBox")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.layer.rasterize")
        })
    }

    @Test func registryCanInspectAndMutateTheActiveDocument() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let before = viewModel.document.layers.count
        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: ["kind": .string("group")]
        ))
        #expect(createResponse.ok)
        #expect(viewModel.document.layers.count == before + 1)
        #expect(viewModel.document.selectedLayer?.isGroup == true)

        let renameResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.rename",
            arguments: ["name": .string("MCP Group")]
        ))
        #expect(renameResponse.ok)
        #expect(viewModel.document.selectedLayer?.name == "MCP Group")
    }

    @Test func registryControlsSelectionsChannelsToolsAndComponents() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.selection.rectangle",
            arguments: [
                "x": .number(10), "y": .number(12),
                "width": .number(40), "height": .number(30)
            ]
        )).ok)
        #expect(viewModel.document.selection?.bounds == CGRect(x: 10, y: 12, width: 40, height: 30))

        #expect(registry.execute(request(operation: "call", name: "xomo.channel.create")).ok)
        #expect(viewModel.document.alphaChannels.count == 1)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.tool.select",
            arguments: ["tool": .string("brush")]
        )).ok)
        #expect(viewModel.selectedTool == .brush)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.component.insert",
            arguments: [
                "component": .string("button"),
                "theme": .string("native"),
                "x": .number(70), "y": .number(80)
            ]
        )).ok)
        #expect(viewModel.document.layers.contains { $0.xomoComponentInstance?.kind == .button })
    }

    @Test func registryCreatesAndInspectsEditablePaths() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.path.action",
            arguments: [
                "action": .string("create"),
                "closed": .bool(true),
                "points": .array([
                    .object(["x": .number(20), "y": .number(20)]),
                    .object(["x": .number(120), "y": .number(20)]),
                    .object(["x": .number(70), "y": .number(100)])
                ])
            ]
        ))
        #expect(createResponse.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.kind == .path)

        let inspectResponse = registry.execute(request(operation: "call", name: "xomo.path.get"))
        #expect(inspectResponse.ok)
        guard case .object(let path) = inspectResponse.result else {
            Issue.record("Expected path object")
            return
        }
        #expect(path["active"] == .bool(true))
        #expect(path["closed"] == .bool(true))
    }

    @Test func registryCreatesAndListsLayerComps() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.layer_comp.action",
            arguments: ["action": .string("create"), "name": .string("Desktop")]
        )).ok)
        let response = registry.execute(request(operation: "call", name: "xomo.layer_comp.list"))
        #expect(response.ok)
        guard case .array(let comps) = response.result else {
            Issue.record("Expected layer comp array")
            return
        }
        #expect(comps.count == 1)
    }

    @Test func registryRoundTripsCompleteProjectData() throws {
        let registry = XomoAutomationRegistry.shared
        let source = makeViewModel()
        registry.register(source)
        source.addLayerGroup()
        source.renameSelectedLayer(to: "Round Trip Group")

        let exported = registry.execute(request(operation: "call", name: "xomo.project.export"))
        #expect(exported.ok)
        guard case .object(let project) = exported.result,
              let base64 = project["base64"]?.stringValue
        else {
            Issue.record("Expected encoded project")
            return
        }

        let destination = makeViewModel()
        registry.register(destination)
        let imported = registry.execute(request(
            operation: "call",
            name: "xomo.project.import",
            arguments: ["base64": .string(base64)]
        ))
        #expect(imported.ok)
        #expect(destination.document.layers.contains { $0.name == "Round Trip Group" && $0.isGroup })
    }

    @Test func registryCreatesCanvasAndEditsText() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.document.create",
            arguments: [
                "width": .number(390),
                "height": .number(844),
                "background": .string("transparent"),
                "exportScale": .number(3)
            ]
        )).ok)
        #expect(viewModel.document.canvasSize == CGSize(width: 390, height: 844))

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("Hello"),
                "fontSize": .number(24),
                "boxWidth": .number(180),
                "boxHeight": .number(96)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxWidth == 180)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 96)
        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: [
                "text": .string("Hello MCP"),
                "bold": .bool(true),
                "underline": .bool(true),
                "strikethrough": .bool(true),
                "alignment": .string("justified"),
                "leftIndent": .number(24),
                "rightIndent": .number(16),
                "firstLineIndent": .number(12),
                "boxHeight": .number(112)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.text == "Hello MCP")
        #expect(viewModel.document.selectedLayer?.textContent?.isBold == true)
        #expect(viewModel.document.selectedLayer?.textContent?.isUnderlined == true)
        #expect(viewModel.document.selectedLayer?.textContent?.isStruckThrough == true)
        #expect(viewModel.document.selectedLayer?.textContent?.alignment == .justified)
        #expect(viewModel.document.selectedLayer?.textContent?.leftIndent == 24)
        #expect(viewModel.document.selectedLayer?.textContent?.rightIndent == 16)
        #expect(viewModel.document.selectedLayer?.textContent?.firstLineIndent == 12)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 112)
        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.convert",
            arguments: ["mode": .string("paragraph")]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.layoutMode == .paragraph)

        let inspectResponse = registry.execute(request(operation: "call", name: "xomo.text.get"))
        guard case .object(let inspectedText) = inspectResponse.result else {
            Issue.record("Expected text result")
            return
        }
        #expect(inspectedText["layoutMode"] == .string("paragraph"))
        #expect(inspectedText["boxHeight"] == .number(112))
        #expect(inspectedText["requiredBoxHeight"] != nil)
        #expect(inspectedText["hasOverflow"] != nil)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: [
                "text": .string("One two three four five six seven eight nine ten eleven twelve"),
                "boxWidth": .number(72),
                "boxHeight": .number(14)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.hasOverflow == true)
        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.fitBox",
            arguments: ["mode": .string("expandHeight")]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.hasOverflow == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textBoxExpandHeight"))
    }

    @Test func registryConfiguresCloneStampSamplingOptions() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("setCloneSource"),
                "x": .number(12),
                "y": .number(18),
                "aligned": .bool(false),
                "sampleSource": .string("allVisible")
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.cloneSourcePoint == CGPoint(x: 12, y: 18))
        #expect(!viewModel.isCloneStampAligned)
        #expect(viewModel.cloneStampSampleSource == .allVisible)
    }

    @Test func registryConfiguresHealingBrushSourceAndSamplingOptions() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("setHealingSource"),
                "x": .number(21),
                "y": .number(34),
                "aligned": .bool(false),
                "sampleSource": .string("currentAndBelow")
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.healingSourcePoint == CGPoint(x: 21, y: 34))
        #expect(!viewModel.isHealingBrushAligned)
        #expect(viewModel.healingBrushSampleSource == .currentAndBelow)
    }

    @Test func registryConfiguresBrushFlowSpacingHardnessAndPressure() {
        let suiteName = "XomoAutomationTests.pressure.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(preferencesDefaults: defaults)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.stroke",
            arguments: [
                "tool": .string("brush"),
                "points": .array([
                    .object(["x": .number(12), "y": .number(18), "pressure": .number(0.2)]),
                    .object(["x": .number(52), "y": .number(18), "pressure": .number(1)])
                ]),
                "size": .number(14),
                "opacity": .number(0.75),
                "hardness": .number(0.35),
                "flow": .number(17),
                "spacing": .number(140),
                "pressureSize": .bool(false),
                "pressureFlow": .bool(true),
                "pressureSensitivity": .number(72)
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.brushSize == 14)
        #expect(viewModel.opacity == 0.75)
        #expect(viewModel.hardness == 0.35)
        #expect(viewModel.brushFlow == 17)
        #expect(viewModel.brushSpacing == 140)
        #expect(!viewModel.brushPressureControlsSize)
        #expect(viewModel.brushPressureControlsFlow)
        #expect(viewModel.brushPressureSensitivity == 72)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.brush"))
    }

    @Test func registryCreatesListsAppliesAndDeletesPersistedBrushPresets() throws {
        let suiteName = "XomoAutomationTests.presets.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(preferencesDefaults: defaults)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.brushSize = 41
        viewModel.hardness = 0.45
        viewModel.brushFlow = 63
        viewModel.brushSpacing = 77

        let create = registry.execute(request(
            operation: "call",
            name: "xomo.brush.preset",
            arguments: ["action": .string("create")]
        ))
        #expect(create.ok)
        let created = try #require(create.result?.arrayValue?.last?.objectValue)
        let id = try #require(created["id"]?.stringValue)
        #expect(created["builtIn"] == .bool(false))
        #expect(created["active"] == .bool(true))

        viewModel.brushSize = 9
        let apply = registry.execute(request(
            operation: "call",
            name: "xomo.brush.preset",
            arguments: ["action": .string("apply"), "id": .string(id)]
        ))
        #expect(apply.ok)
        #expect(viewModel.brushSize == 41)
        #expect(viewModel.hardness == 0.45)
        #expect(viewModel.brushFlow == 63)
        #expect(viewModel.brushSpacing == 77)

        let delete = registry.execute(request(
            operation: "call",
            name: "xomo.brush.preset",
            arguments: ["action": .string("delete"), "id": .string(id)]
        ))
        #expect(delete.ok)
        #expect(viewModel.customBrushPresets.isEmpty)
        #expect(delete.result?.arrayValue?.count == ImageEditorBrushPreset.defaultPresets.count)
    }

    @Test func registryRecursivelyExpandsAndCollapsesSelectedLayerGroups() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        var parent = ImageEditorLayer.group(name: "Parent", size: viewModel.document.canvasSize)
        var child = ImageEditorLayer.group(name: "Child", size: viewModel.document.canvasSize)
        child.groupID = parent.id
        parent.isGroupExpanded = true
        child.isGroupExpanded = true
        viewModel.document.layers = [child, parent]
        viewModel.document.selectedLayerID = parent.id
        viewModel.document.selectedLayerIDs = [parent.id]
        registry.register(viewModel)

        let collapse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("collapseSelectedGroups")]
        ))
        #expect(collapse.ok)
        #expect(viewModel.document.layers.allSatisfy { layer in !layer.isGroupExpanded })

        let expand = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("expandSelectedGroups")]
        ))
        #expect(expand.ok)
        #expect(viewModel.document.layers.allSatisfy { layer in layer.isGroupExpanded })
    }

    @Test func registryUsesTheSameSingleBackgroundConversionRulesAsTheEditor() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        let regularLayerID = try #require(viewModel.document.selectedLayerID)
        let initialLayerIDs = viewModel.document.layers.map(\.id)
        let initialHistoryCount = viewModel.document.history.count

        let rejected = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("layerToBackground")]
        ))

        #expect(rejected.ok)
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.selectLayer(backgroundID)
        let unlock = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("backgroundToLayer")]
        ))
        #expect(unlock.ok)
        #expect(!viewModel.document.layers[0].isLocked)

        viewModel.selectLayer(regularLayerID)
        let convert = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("layerToBackground")]
        ))

        #expect(convert.ok)
        #expect(viewModel.document.layers.first?.id == regularLayerID)
        #expect(viewModel.document.layers.first?.isLocked == true)
        #expect(viewModel.document.layers.first?.name == L10n.text("imageEditor.layer.background"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.backgroundFromLayer"))
    }

    @Test func registryRasterizesOnlyTheRequestedLayerContentTarget() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        viewModel.textValue = "MCP Type"
        viewModel.textSize = 24
        viewModel.addText(at: CGPoint(x: 20, y: 18))
        let textIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[textIndex].name = "MCP Headline"
        viewModel.document.layers[textIndex].style.strokeEnabled = true
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.layer.rasterize",
            arguments: ["target": .string("type")]
        ))

        #expect(response.ok)
        let rasterized = try #require(viewModel.document.selectedLayer)
        #expect(rasterized.kind.isPixel)
        #expect(rasterized.name == "MCP Headline")
        #expect(rasterized.hasLayerEffects)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterize"))
    }

    @Test func registryReordersCollapsedGroupsAsVisibleSubtrees() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let bottom = ImageEditorLayer.blank(name: "Bottom", size: viewModel.document.canvasSize)
        var group = ImageEditorLayer.group(name: "Collapsed", size: viewModel.document.canvasSize)
        var child = ImageEditorLayer.blank(name: "Child", size: viewModel.document.canvasSize)
        let top = ImageEditorLayer.blank(name: "Top", size: viewModel.document.canvasSize)
        child.groupID = group.id
        group.isGroupExpanded = false
        viewModel.document.layers = [bottom, child, group, top]
        viewModel.document.selectedLayerID = group.id
        viewModel.document.selectedLayerIDs = [group.id]
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.layer.order",
            arguments: ["direction": .string("down")]
        ))

        #expect(response.ok)
        #expect(viewModel.visibleLayerRows.map(\.id) == [top.id, bottom.id, group.id])
        #expect(viewModel.document.layers.first { $0.id == child.id }?.groupID == group.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMove"))
    }

    @Test func registryGroupsAndUngroupsHierarchyWhileSkippingLockedSelection() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let bottom = ImageEditorLayer.blank(name: "Bottom", size: viewModel.document.canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: viewModel.document.canvasSize)
        let top = ImageEditorLayer.blank(name: "Top", size: viewModel.document.canvasSize)
        locked.isLocked = true
        viewModel.document.layers = [bottom, locked, top]
        viewModel.document.selectedLayerID = top.id
        viewModel.document.selectedLayerIDs = [bottom.id, locked.id, top.id]
        registry.register(viewModel)

        let groupResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.group"
        ))

        #expect(groupResponse.ok)
        let groupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.layers.map(\.id) == [locked.id, bottom.id, top.id, groupID])
        #expect(viewModel.document.selectedLayerIDs == [locked.id, groupID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGroupSelected"))

        let ungroupResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.ungroup"
        ))

        #expect(ungroupResponse.ok)
        #expect(viewModel.document.layers.map(\.id) == [locked.id, bottom.id, top.id])
        #expect(viewModel.document.selectedLayerIDs == [locked.id, bottom.id, top.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUngroup"))
    }

    @Test func registryMergesSelectedSiblingLayersWhilePreservingLockedSelection() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let bottom = ImageEditorLayer.blank(name: "Bottom", size: viewModel.document.canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: viewModel.document.canvasSize)
        let top = ImageEditorLayer.blank(name: "Top", size: viewModel.document.canvasSize)
        locked.isLocked = true
        viewModel.document.layers = [bottom, locked, top]
        viewModel.document.selectedLayerID = top.id
        viewModel.document.selectedLayerIDs = [bottom.id, locked.id, top.id]
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.layer.merge_selected"
        ))

        #expect(response.ok)
        #expect(viewModel.document.layers.count == 2)
        #expect(viewModel.document.layers.last?.id == locked.id)
        #expect(viewModel.document.selectedLayerIDs.contains(locked.id))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeSelected"))
    }

    @Test func registryStampsSelectedLayersAndFlattensToALockedBackground() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let lower = ImageEditorLayer.blank(name: "Lower", size: viewModel.document.canvasSize)
        let upper = ImageEditorLayer.blank(name: "Upper", size: viewModel.document.canvasSize)
        viewModel.document.layers = [lower, upper]
        viewModel.document.selectedLayerID = upper.id
        viewModel.document.selectedLayerIDs = [lower.id, upper.id]
        registry.register(viewModel)

        let stampResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.stamp_selected"
        ))

        #expect(stampResponse.ok)
        #expect(viewModel.document.layers.count == 3)
        #expect(viewModel.document.selectedLayer?.name == L10n.text("imageEditor.layer.selectedStampName"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStampSelected"))

        let flattenResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.flatten"
        ))

        #expect(flattenResponse.ok)
        let background = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == 1)
        #expect(background.name == L10n.text("imageEditor.layer.background"))
        #expect(background.isLocked)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFlatten"))
    }

    @Test func registryMovesLayerSubtreesIntoAndOutOfGroupsAtVisibleBoundaries() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let moving = ImageEditorLayer.blank(name: "Moving", size: viewModel.document.canvasSize)
        var existing = ImageEditorLayer.blank(name: "Existing", size: viewModel.document.canvasSize)
        let target = ImageEditorLayer.group(name: "Target", size: viewModel.document.canvasSize)
        existing.groupID = target.id
        viewModel.document.layers = [moving, existing, target]
        viewModel.document.selectedLayerID = moving.id
        viewModel.document.selectedLayerIDs = [moving.id]
        registry.register(viewModel)

        let moveIntoResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("moveIntoGroup")]
        ))

        #expect(moveIntoResponse.ok)
        #expect(viewModel.document.layers.map(\.id) == [existing.id, moving.id, target.id])
        #expect(viewModel.document.layers.first { $0.id == moving.id }?.groupID == target.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveIntoGroup"))

        let moveOutResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.action",
            arguments: ["action": .string("moveOutOfGroup")]
        ))

        #expect(moveOutResponse.ok)
        #expect(viewModel.document.layers.map(\.id) == [existing.id, target.id, moving.id])
        #expect(viewModel.document.layers.first { $0.id == moving.id }?.groupID == nil)
        #expect(viewModel.document.selectedLayerIDs == Set([moving.id]))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveOutOfGroup"))
    }

    @Test func registryDuplicatesLayerSubtreesInsideTheirOriginalParents() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        var child = ImageEditorLayer.blank(name: "Child", size: viewModel.document.canvasSize)
        let selectedGroup = ImageEditorLayer.group(name: "Selected Group", size: viewModel.document.canvasSize)
        var peer = ImageEditorLayer.blank(name: "Peer", size: viewModel.document.canvasSize)
        let peerGroup = ImageEditorLayer.group(name: "Peer Group", size: viewModel.document.canvasSize)
        child.groupID = selectedGroup.id
        peer.groupID = peerGroup.id
        child.linkedLayerIDs = [peer.id]
        peer.linkedLayerIDs = [child.id]
        viewModel.document.layers = [child, selectedGroup, peer, peerGroup]
        viewModel.document.selectedLayerIDs = [selectedGroup.id, peer.id]
        viewModel.document.selectedLayerID = peer.id
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.layer.duplicate"
        ))

        #expect(response.ok)
        let groupCopy = try #require(viewModel.document.layers.first {
            $0.id != selectedGroup.id
                && $0.name == L10n.format("imageEditor.layer.copyName", selectedGroup.name)
        })
        let childCopy = try #require(viewModel.document.layers.first {
            $0.id != child.id && $0.groupID == groupCopy.id
        })
        let peerCopy = try #require(viewModel.document.layers.first {
            $0.id != peer.id
                && $0.name == L10n.format("imageEditor.layer.copyName", peer.name)
        })
        #expect(viewModel.document.layers.map(\.id) == [
            child.id,
            selectedGroup.id,
            childCopy.id,
            groupCopy.id,
            peer.id,
            peerCopy.id,
            peerGroup.id
        ])
        #expect(childCopy.name == child.name)
        #expect(childCopy.linkedLayerIDs == Set([peerCopy.id]))
        #expect(peerCopy.linkedLayerIDs == Set([childCopy.id]))
        #expect(viewModel.document.selectedLayerIDs == Set([groupCopy.id, peerCopy.id]))
        #expect(viewModel.document.selectedLayerID == peerCopy.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))
    }

    @Test func registryDeletesUnlockedLayerSubtreesAndPreservesLockedSelection() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        var child = ImageEditorLayer.blank(name: "Child", size: viewModel.document.canvasSize)
        let selectedGroup = ImageEditorLayer.group(name: "Selected Group", size: viewModel.document.canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: viewModel.document.canvasSize)
        let survivor = ImageEditorLayer.blank(name: "Survivor", size: viewModel.document.canvasSize)
        child.groupID = selectedGroup.id
        locked.isLocked = true
        viewModel.document.layers = [locked, child, selectedGroup, survivor]
        viewModel.document.selectedLayerIDs = [locked.id, selectedGroup.id]
        viewModel.document.selectedLayerID = selectedGroup.id
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.layer.delete"
        ))

        #expect(response.ok)
        #expect(viewModel.document.layers.map(\.id) == [locked.id, survivor.id])
        #expect(viewModel.document.selectedLayerIDs == [locked.id])
        #expect(viewModel.document.selectedLayerID == locked.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDelete"))
    }

    @Test func registryRunsDestinationPatchWithFeatherThroughSpecialPaintTool() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 30, y: 30))

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("patch"),
                "mode": .string("destination"),
                "feather": .number(4),
                "opacity": .number(0.75),
                "points": .array([
                    .object(["x": .number(20), "y": .number(20)]),
                    .object(["x": .number(50), "y": .number(20)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.patchMode == .destination)
        #expect(viewModel.feather == 4)
        #expect(viewModel.opacity == 0.75)
        #expect(viewModel.document.selection?.bounds == CGRect(x: 40, y: 10, width: 20, height: 20))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPatch"))
    }

    private func request(
        operation: String,
        name: String? = nil,
        arguments: [String: XomoJSONValue]? = nil
    ) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: operation,
            name: name,
            arguments: arguments
        )
    }

    private func makeViewModel(
        preferencesDefaults: UserDefaults = .standard
    ) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "automation",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240)),
            preferencesDefaults: preferencesDefaults
        ) { _ in }
    }
}
