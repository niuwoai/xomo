import AppKit
import Combine
import Testing
@testable import musepic

@MainActor
struct XomoAutomationTests {
    @Test func mutatingAutomationCallPublishesImmediateEditorRefresh() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let layerID = try #require(viewModel.document.selectedLayerID)
        var refreshCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            refreshCount += 1
        }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.layer.set_visibility",
            arguments: [
                "id": .string(layerID.uuidString),
                "visible": .bool(false)
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.document.selectedLayer?.isVisible == false)
        #expect(refreshCount > 0)
        withExtendedLifetime(cancellable) {}
    }

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
        #expect(tools.count == 146)
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.layer.list")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.layer.selection_bounds")
        })
        let transformReferenceTool = try #require(tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string("xomo.layer.transform_reference") })
        #expect(transformReferenceTool["inputSchema"]?.objectValue?["required"] == .array([
            .string("action")
        ]))
        #expect(
            transformReferenceTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["action"]?.objectValue?["enum"] == .array([
                    .string("set"), .string("reset")
                ])
        )
        let objectSelectTool = try #require(tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string("xomo.object.select_at") })
        #expect(objectSelectTool["inputSchema"]?.objectValue?["required"] == .array([
            .string("x"), .string("y")
        ]))
        #expect(objectSelectTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["mode"]?.objectValue?["enum"] == .array([
            .string("auto"), .string("component"), .string("deep")
        ]))
        let documentTool = try #require(tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string("xomo.document.get") })
        #expect(
            documentTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["histogramChannel"]?
                .objectValue?["enum"]?.arrayValue
                == ImageEditorHistogramChannel.allCases.map { .string($0.rawValue) }
        )
        #expect(
            documentTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["histogramSource"]?
                .objectValue?["enum"]?.arrayValue
                == ImageEditorHistogramSource.allCases.map { .string($0.rawValue) }
        )
        let colorSamplerAddTool = try #require(tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string("xomo.color_sampler.add") })
        #expect(colorSamplerAddTool["inputSchema"]?.objectValue?["required"] == .array([
            .string("x"), .string("y")
        ]))
        #expect(
            colorSamplerAddTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["sampleSize"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorColorSamplerSampleSize.allCases.map { .string($0.rawValue) }
        )
        #expect(
            colorSamplerAddTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["sampleSource"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorColorSamplerSource.allCases.map { .string($0.rawValue) }
        )
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.color_sampler.list")
        })
        let colorSamplerMoveTool = try #require(tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string("xomo.color_sampler.move") })
        #expect(colorSamplerMoveTool["inputSchema"]?.objectValue?["required"] == .array([
            .string("id"), .string("x"), .string("y")
        ]))
        let colorSamplerRemoveTool = try #require(tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string("xomo.color_sampler.remove") })
        #expect(colorSamplerRemoveTool["inputSchema"]?.objectValue?["required"] == .array([
            .string("id")
        ]))
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.color_sampler.clear")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.channel.action")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.path.action")
        })
        guard let pathTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.path.action") }) else {
            Issue.record("Expected xomo.path.action tool schema")
            return
        }
        #expect(pathTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("nudgeAnchor")) == true)
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.clipboard.action")
        })
        guard let clipboardTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.clipboard.action") }) else {
            Issue.record("Expected xomo.clipboard.action tool schema")
            return
        }
        #expect(clipboardTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["action"]?.objectValue?["enum"] == .array([
            .string("pasteAsLayer"),
            .string("pasteIntoSelection"),
            .string("pasteInPlace"),
            .string("copySelection"),
            .string("cutSelection"),
            .string("copyMerged"),
            .string("copySelectedLayers")
        ]))
        guard let selectionModifyTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.selection.modify") }) else {
            Issue.record("Expected xomo.selection.modify tool schema")
            return
        }
        #expect(selectionModifyTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["amount"]?.objectValue?["type"] == .string("number"))
        guard let magicTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.selection.magic") }) else {
            Issue.record("Expected xomo.selection.magic tool schema")
            return
        }
        #expect(magicTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["tolerance"]?.objectValue?["type"] == .string("number"))
        #expect(magicTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["contiguous"]?.objectValue?["type"] == .string("boolean"))
        #expect(selectionModifyTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["tolerance"]?.objectValue?["type"] == .string("number"))
        #expect(selectionModifyTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["threshold"]?.objectValue?["type"] == .string("number"))
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
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.component.tokens")
        })
        guard let layerListTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.layer.list") }) else {
            Issue.record("Expected xomo.layer.list tool schema")
            return
        }
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaBindings"]?.objectValue?["enum"] == .array([
            .string("all"),
            .string("bound"),
            .string("unbound")
        ]))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaConstraints"]?.objectValue?["enum"] == .array([
            .string("all"),
            .string("constrained"),
            .string("overridden"),
            .string("conflicted")
        ]))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaSource"]?.objectValue?["enum"] == .array([
            .string("all"),
            .string("imported"),
            .string("local")
        ]))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaNodeType"]?.objectValue?["type"] == .string("string"))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaNodeId"]?.objectValue?["type"] == .string("string"))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaFileKey"]?.objectValue?["type"] == .string("string"))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaResourceType"]?.objectValue?["enum"] == .array([
            .string("design"), .string("file"), .string("proto"), .string("board"),
            .string("slides"), .string("deck"), .string("site"), .string("buzz"), .string("make")
        ]))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaImportScope"]?.objectValue?["enum"] == .array([
            .string("designDocument"), .string("figJamBoard"), .string("previewOnly")
        ]))
        #expect(layerListTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["figmaComponentRole"]?.objectValue?["enum"] == .array([
            .string("all"),
            .string("none"),
            .string("COMPONENT"),
            .string("COMPONENT_SET"),
            .string("INSTANCE")
        ]))
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.figma.bindings")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.figma.component_properties")
        })
        guard let sizeConstraintsTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.figma.size_constraints") }) else {
            Issue.record("Expected xomo.figma.size_constraints tool schema")
            return
        }
        #expect(sizeConstraintsTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["field"]?.objectValue?["enum"] == .array([
            .string("minWidth"),
            .string("maxWidth"),
            .string("minHeight"),
            .string("maxHeight")
        ]))
        #expect(sizeConstraintsTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["axis"]?.objectValue?["enum"] == .array([
            .string("width"),
            .string("height")
        ]))
        #expect(sizeConstraintsTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("resolve")) == true)
        #expect(sizeConstraintsTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("resolveAll")) == true)
        guard let imageFillTool = tools.compactMap({ tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }).first(where: { $0["name"] == .string("xomo.figma.image_fill") }) else {
            Issue.record("Expected xomo.figma.image_fill tool schema")
            return
        }
        #expect(imageFillTool["inputSchema"]?.objectValue?["properties"]?.objectValue?["property"]?.objectValue?["enum"]?.arrayValue?.contains(.string("m22")) == true)
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.figma.link")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.component.instance")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.selection.quick_mask")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.view.pan")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.psd.inspect")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.psd.open")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.psd.save")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.slice.update")
        })
    }

    @Test func smartFilterAutomationAddsListsAndUpdatesResultOpacityAndBlendMode() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let manageTool = try #require(automationTool(named: "xomo.smart_filter.manage", in: toolsResponse))
        let manageProperties = try #require(manageTool["inputSchema"]?.objectValue?["properties"]?.objectValue)
        #expect(manageProperties["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("load")) == true)
        #expect(manageProperties["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("setOpacity")) == true)
        #expect(manageProperties["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("setBlendMode")) == true)
        #expect(manageProperties["action"]?.objectValue?["enum"]?.arrayValue?.contains(.string("duplicate")) == true)
        #expect(manageProperties["opacity"]?.objectValue?["type"] == .string("number"))
        #expect(manageProperties["blendMode"]?.objectValue?["enum"]?.arrayValue?.contains(.string("multiply")) == true)
        #expect(manageProperties["blendMode"]?.objectValue?["enum"]?.arrayValue?.contains(.string("passThrough")) == false)

        let addResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.add",
            arguments: [
                "filter": .string(ImageEditorFilter.median.rawValue),
                "intensity": .number(1),
                "opacity": .number(0.4),
                "blendMode": .string(ImageEditorBlendMode.softLight.rawValue)
            ]
        ))
        #expect(addResponse.ok)
        #expect(addResponse.result?.objectValue?["addedLayerCount"] == .number(1))
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        #expect(viewModel.smartFilterOpacity(filterID) == 0.4)
        #expect(viewModel.smartFilterBlendMode(filterID) == .softLight)

        let listResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.list"
        ))
        let listedFilter = try #require(listResponse.result?.arrayValue?.first?.objectValue)
        #expect(listedFilter["opacity"] == .number(0.4))
        #expect(listedFilter["blendMode"] == .string("softLight"))

        viewModel.selectedFilter = .sharpen
        viewModel.filterIntensity = 0.1
        let historyCountBeforeLoad = viewModel.document.history.count
        let loadResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(filterID.uuidString),
                "action": .string("load")
            ]
        ))
        #expect(loadResponse.ok)
        #expect(viewModel.selectedFilter == .median)
        #expect(viewModel.filterIntensity == 1)
        #expect(viewModel.isSmartFilterLoadedForEditing(filterID))
        #expect(viewModel.document.history.count == historyCountBeforeLoad)

        let updateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(filterID.uuidString),
                "action": .string("setOpacity"),
                "opacity": .number(0.25)
            ]
        ))
        #expect(updateResponse.ok)
        #expect(updateResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.smartFilterOpacity(filterID) == 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterOpacity"))

        let blendResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(filterID.uuidString),
                "action": .string("setBlendMode"),
                "blendMode": .string(ImageEditorBlendMode.multiply.rawValue)
            ]
        ))
        #expect(blendResponse.ok)
        #expect(blendResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.smartFilterBlendMode(filterID) == .multiply)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterBlendMode"))

        let duplicateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(filterID.uuidString),
                "action": .string("duplicate")
            ]
        ))
        #expect(duplicateResponse.ok)
        #expect(duplicateResponse.result?.objectValue?["duplicatedLayerCount"] == .number(1))
        let filters = try #require(viewModel.document.selectedLayer?.smartFilters)
        #expect(filters.count == 2)
        #expect(filters[0].id == filterID)
        #expect(filters[1].id != filterID)
        #expect(filters[1].kind == filters[0].kind)
        #expect(filters[1].settings == filters[0].settings)
        #expect(filters[1].normalizedOpacity == filters[0].normalizedOpacity)
        #expect(filters[1].normalizedBlendMode == filters[0].normalizedBlendMode)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterDuplicate"))

        let duplicateID = filters[1].id
        let moveUpResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(duplicateID.uuidString),
                "action": .string("moveUp")
            ]
        ))
        #expect(moveUpResponse.ok)
        #expect(moveUpResponse.result?.objectValue?["movedLayerCount"] == .number(1))
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [duplicateID, filterID])

        let moveDownResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(duplicateID.uuidString),
                "action": .string("moveDown")
            ]
        ))
        #expect(moveDownResponse.ok)
        #expect(moveDownResponse.result?.objectValue?["movedLayerCount"] == .number(1))
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [filterID, duplicateID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterMove"))

        let outOfBoundsMoveResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(duplicateID.uuidString),
                "action": .string("moveDown")
            ]
        ))
        #expect(!outOfBoundsMoveResponse.ok)
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [filterID, duplicateID])

        let removeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(duplicateID.uuidString),
                "action": .string("remove")
            ]
        ))
        #expect(removeResponse.ok)
        #expect(removeResponse.result?.objectValue?["removedLayerCount"] == .number(1))
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [filterID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterRemove"))

        let missingRemoveResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(duplicateID.uuidString),
                "action": .string("remove")
            ]
        ))
        #expect(!missingRemoveResponse.ok)

        let clearResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.clear"
        ))
        #expect(clearResponse.ok)
        #expect(clearResponse.result?.objectValue?["clearedLayerCount"] == .number(1))
        #expect(viewModel.document.selectedLayer?.smartFilters.isEmpty == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterClear"))

        let historyCountBeforeEmptyClear = viewModel.document.history.count
        let emptyClearResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.clear"
        ))
        #expect(!emptyClearResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeEmptyClear)
    }

    @Test func smartFilterAutomationReportsAffectedLayerCountsAndRejectsNoOpMutations() throws {
        let viewModel = makeViewModel()
        let primaryID = try #require(viewModel.document.selectedLayerID)
        let peer = ImageEditorLayer.blank(name: "Peer", size: viewModel.document.canvasSize)
        let peerID = peer.id
        var locked = ImageEditorLayer.blank(name: "Locked", size: viewModel.document.canvasSize)
        locked.isLocked = true
        let lockedID = locked.id
        viewModel.document.layers.append(contentsOf: [peer, locked])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, peerID, lockedID]

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let addResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.add",
            arguments: [
                "filter": .string(ImageEditorFilter.median.rawValue),
                "intensity": .number(0.4)
            ]
        ))
        #expect(addResponse.ok)
        #expect(addResponse.result?.objectValue?["addedLayerCount"] == .number(2))
        let primaryFilterID = try #require(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.first?.id
        )
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.count == 1)
        #expect(viewModel.document.layers.first { $0.id == lockedID }?.smartFilters.isEmpty == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAddSelected"))

        let updateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("update"),
                "intensity": .number(0.7)
            ]
        ))
        #expect(updateResponse.ok)
        #expect(updateResponse.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.first?.normalizedIntensity == 0.7)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.first?.normalizedIntensity == 0.7)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdateSelected"))

        let historyCountBeforeNoOp = viewModel.document.history.count
        let noOpUpdateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("update"),
                "intensity": .number(0.7)
            ]
        ))
        #expect(!noOpUpdateResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeNoOp)

        let primaryIndex = try #require(viewModel.document.layers.firstIndex { $0.id == primaryID })
        viewModel.document.layers[primaryIndex].isLocked = true
        let peerOnlyUpdateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("update"),
                "intensity": .number(0.9)
            ]
        ))
        #expect(peerOnlyUpdateResponse.ok)
        #expect(peerOnlyUpdateResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.first?.normalizedIntensity == 0.7)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.first?.normalizedIntensity == 0.9)
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryFilterID))

        let toggleResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.toggle",
            arguments: ["id": .string(primaryFilterID.uuidString)]
        ))
        #expect(toggleResponse.ok)
        #expect(toggleResponse.result?.objectValue?["toggledLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.first?.isEnabled == true)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.first?.isEnabled == false)

        let historyCountBeforeNoOpToggle = viewModel.document.history.count
        let noOpToggleResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.toggle",
            arguments: ["id": .string(primaryFilterID.uuidString)]
        ))
        #expect(!noOpToggleResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeNoOpToggle)

        let opacityResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("setOpacity"),
                "opacity": .number(0.45)
            ]
        ))
        #expect(opacityResponse.ok)
        #expect(opacityResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.first?.normalizedOpacity == 1)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.first?.normalizedOpacity == 0.45)

        let historyCountBeforeNoOpOpacity = viewModel.document.history.count
        let noOpOpacityResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("setOpacity"),
                "opacity": .number(0.45)
            ]
        ))
        #expect(!noOpOpacityResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeNoOpOpacity)

        let blendModeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("setBlendMode"),
                "blendMode": .string(ImageEditorBlendMode.multiply.rawValue)
            ]
        ))
        #expect(blendModeResponse.ok)
        #expect(blendModeResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.first?.normalizedBlendMode == .normal)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.first?.normalizedBlendMode == .multiply)

        let historyCountBeforeNoOpBlendMode = viewModel.document.history.count
        let noOpBlendModeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("setBlendMode"),
                "blendMode": .string(ImageEditorBlendMode.multiply.rawValue)
            ]
        ))
        #expect(!noOpBlendModeResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeNoOpBlendMode)

        let duplicateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("duplicate")
            ]
        ))
        #expect(duplicateResponse.ok)
        #expect(duplicateResponse.result?.objectValue?["duplicatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.count == 1)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.count == 2)
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryFilterID))

        let configuredAddResponse = registry.execute(request(
            operation: "call",
            name: "xomo.filter.configure",
            arguments: [
                "filter": .string(ImageEditorFilter.lensCorrection.rawValue),
                "action": .string("addSmartFilter"),
                "settings": .object([
                    "intensity": .number(0.6),
                    "lensDistortion": .number(2)
                ])
            ]
        ))
        #expect(configuredAddResponse.ok)
        #expect(configuredAddResponse.result?.objectValue?["addedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.count == 1)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.count == 3)
        let configuredFilter = try #require(
            viewModel.document.layers.first { $0.id == peerID }?.smartFilters.last
        )
        #expect(configuredFilter.kind == .lensCorrection)
        #expect(configuredFilter.normalizedSettings.lensDistortion == 1)

        let peerFilterOrder = try #require(
            viewModel.document.layers.first { $0.id == peerID }?.smartFilters.map(\.id)
        )
        let movePeerDownResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("moveDown")
            ]
        ))
        #expect(movePeerDownResponse.ok)
        #expect(movePeerDownResponse.result?.objectValue?["movedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.count == 1)
        #expect(
            viewModel.document.layers.first { $0.id == peerID }?.smartFilters.map(\.id)
                == [peerFilterOrder[1], peerFilterOrder[0], peerFilterOrder[2]]
        )
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryFilterID))

        let removeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("remove")
            ]
        ))
        #expect(removeResponse.ok)
        #expect(removeResponse.result?.objectValue?["removedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.count == 1)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.count == 2)
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryFilterID))

        let peerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == peerID })
        viewModel.document.layers[peerIndex].isLocked = true
        let historyCountBeforeRejectedAdd = viewModel.document.history.count
        let rejectedAddResponse = registry.execute(request(
            operation: "call",
            name: "xomo.filter.configure",
            arguments: [
                "filter": .string(ImageEditorFilter.pixelate.rawValue),
                "action": .string("addSmartFilter")
            ]
        ))
        #expect(!rejectedAddResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeRejectedAdd)

        let rejectedDuplicateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("duplicate")
            ]
        ))
        #expect(!rejectedDuplicateResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeRejectedAdd)

        let rejectedRemoveResponse = registry.execute(request(
            operation: "call",
            name: "xomo.smart_filter.manage",
            arguments: [
                "id": .string(primaryFilterID.uuidString),
                "action": .string("remove")
            ]
        ))
        #expect(!rejectedRemoveResponse.ok)
        #expect(viewModel.document.history.count == historyCountBeforeRejectedAdd)
    }

    @Test func registryCreatesListsAndDeletesNamedSlices() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.createRectSelection(from: CGPoint(x: 24, y: 18), to: CGPoint(x: 84, y: 58))

        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.slice.create",
            arguments: ["name": .string("Hero")]
        ))
        #expect(createResponse.ok)
        guard case .object(let created) = createResponse.result,
              case .string(let rawID) = created["id"],
              let id = UUID(uuidString: rawID)
        else {
            Issue.record("Expected created slice payload")
            return
        }
        #expect(created["name"] == .string("Hero"))
        #expect(created["width"] == .number(60))
        #expect(created["height"] == .number(40))
        #expect(viewModel.isSlicesPanelVisible)
        #expect(viewModel.selectSlice(id: id)?.name == "Hero")
        #expect(viewModel.statusText == L10n.format("imageEditor.status.sliceSelected", "Hero"))

        let updateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.slice.update",
            arguments: [
                "id": .string(id.uuidString),
                "name": .string("Hero Updated"),
                "x": .number(30),
                "y": .number(20),
                "width": .number(70),
                "height": .number(44)
            ]
        ))
        #expect(updateResponse.ok)
        #expect(updateResponse.result?.objectValue?["name"] == .string("Hero Updated"))
        #expect(updateResponse.result?.objectValue?["width"] == .number(70))
        let updated = try #require(viewModel.slice(with: id))
        #expect(updated.frame == CGRect(x: 30, y: 20, width: 70, height: 44))
        #expect(viewModel.exportSettings.sliceID == id)

        let listResponse = registry.execute(request(operation: "call", name: "xomo.slice.list"))
        #expect(listResponse.ok)
        #expect(listResponse.result?.arrayValue?.count == 1)

        let deleteResponse = registry.execute(request(
            operation: "call",
            name: "xomo.slice.delete",
            arguments: ["id": .string(id.uuidString)]
        ))
        #expect(deleteResponse.ok)
        #expect(viewModel.document.slices.isEmpty)
        #expect(viewModel.exportSettings.scope == .composited)
    }

    @Test func registryCreatesListsAndDeletesNamedHotspots() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.createRectSelection(from: CGPoint(x: 24, y: 18), to: CGPoint(x: 84, y: 58))

        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.hotspot.create",
            arguments: [
                "name": .string("Hero link"),
                "url": .string("https://example.com/hero")
            ]
        ))
        #expect(createResponse.ok)
        guard case .object(let created) = createResponse.result,
              case .string(let rawID) = created["id"],
              let id = UUID(uuidString: rawID)
        else {
            Issue.record("Expected created hotspot payload")
            return
        }
        #expect(created["name"] == .string("Hero link"))
        #expect(created["url"] == .string("https://example.com/hero"))
        #expect(created["width"] == .number(60))
        #expect(created["height"] == .number(40))
        #expect(viewModel.selectedHotspotID == id)
        #expect(viewModel.isHotspotsPanelVisible)
        #expect(viewModel.selectHotspot(id: id)?.name == "Hero link")
        #expect(viewModel.statusText == L10n.format("imageEditor.status.hotspotSelected", "Hero link"))

        let listResponse = registry.execute(request(operation: "call", name: "xomo.hotspot.list"))
        #expect(listResponse.ok)
        #expect(listResponse.result?.arrayValue?.count == 1)

        let deleteResponse = registry.execute(request(
            operation: "call",
            name: "xomo.hotspot.delete",
            arguments: ["id": .string(id.uuidString)]
        ))
        #expect(deleteResponse.ok)
        #expect(viewModel.document.hotspots.isEmpty)
        #expect(viewModel.selectedHotspotID == nil)
    }

    @Test func selectedDeliveryObjectsCanBeDeletedThroughSharedDeleteCommand() throws {
        let viewModel = makeViewModel()

        viewModel.createRectSelection(from: CGPoint(x: 24, y: 18), to: CGPoint(x: 84, y: 58))
        let slice = try #require(viewModel.createSliceFromCurrentSelection(name: "Hero slice"))
        #expect(viewModel.deleteSelectedDeliveryObjectIfNeeded())
        #expect(viewModel.document.slices.isEmpty)
        #expect(viewModel.exportSettings.scope == .composited)
        #expect(viewModel.slice(with: slice.id) == nil)

        viewModel.createRectSelection(from: CGPoint(x: 100, y: 72), to: CGPoint(x: 164, y: 112))
        let hotspot = try #require(viewModel.createHotspotFromCurrentSelection(name: "Hero link"))
        #expect(viewModel.deleteSelectedDeliveryObjectIfNeeded())
        #expect(viewModel.document.hotspots.isEmpty)
        #expect(viewModel.selectedHotspotID == nil)
        #expect(viewModel.hotspot(with: hotspot.id) == nil)
    }

    @Test func selectedDeliveryObjectsCanBeNudgedWithoutChangingTheirSize() throws {
        let viewModel = makeViewModel()

        viewModel.createRectSelection(from: CGPoint(x: 24, y: 18), to: CGPoint(x: 84, y: 58))
        let slice = try #require(viewModel.createSliceFromCurrentSelection(name: "Hero slice"))
        let sliceSize = slice.frame.size
        #expect(viewModel.nudgeSelectedDeliveryObject(by: CGSize(width: 5, height: -5)))
        let nudgedSlice = try #require(viewModel.slice(with: slice.id))
        #expect(nudgedSlice.frame.origin == CGPoint(x: 29, y: 13))
        #expect(nudgedSlice.frame.size == sliceSize)

        viewModel.createRectSelection(from: CGPoint(x: 240, y: 150), to: CGPoint(x: 280, y: 190))
        let hotspot = try #require(viewModel.createHotspotFromCurrentSelection(name: "Hero link"))
        let hotspotSize = hotspot.frame.size
        #expect(viewModel.nudgeSelectedDeliveryObject(by: CGSize(width: 50, height: 50)))
        let nudgedHotspot = try #require(viewModel.hotspot(with: hotspot.id))
        #expect(nudgedHotspot.frame.maxX <= viewModel.document.canvasSize.width)
        #expect(nudgedHotspot.frame.maxY <= viewModel.document.canvasSize.height)
        #expect(nudgedHotspot.frame.size == hotspotSize)
    }

    @Test func registryUpdatesAndExportsNamedHotspotsAsHTML() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.createRectSelection(from: CGPoint(x: 24, y: 18), to: CGPoint(x: 84, y: 58))

        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.hotspot.create",
            arguments: ["name": .string("Hero"), "url": .string("https://example.com/old")]
        ))
        #expect(createResponse.ok)
        let id = try #require(createResponse.result?.objectValue?["id"]?.stringValue)

        let updateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.hotspot.update",
            arguments: [
                "id": .string(id),
                "name": .string("Hero CTA"),
                "url": .string("https://example.com/hero"),
                "x": .number(30),
                "y": .number(20),
                "width": .number(70),
                "height": .number(44)
            ]
        ))
        #expect(updateResponse.ok)
        #expect(updateResponse.result?.objectValue?["name"] == .string("Hero CTA"))
        #expect(updateResponse.result?.objectValue?["width"] == .number(70))

        let exportResponse = registry.execute(request(
            operation: "call",
            name: "xomo.hotspot.export_html"
        ))
        #expect(exportResponse.ok)
        #expect(exportResponse.result?.objectValue?["mimeType"] == .string("text/html"))
        let encoded = try #require(exportResponse.result?.objectValue?["base64"]?.stringValue)
        let html = try #require(Data(base64Encoded: encoded).flatMap { String(data: $0, encoding: .utf8) })
        #expect(html.contains("usemap=\"#xomo-hotspots\""))
        #expect(html.contains("https://example.com/hero"))
        #expect(html.contains("Hero CTA"))
    }

    @Test func registryPastesXomoClipboardLayerInPlace() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let frame = CGRect(x: 36, y: 42, width: 48, height: 32)
        let image = try #require(NSImage.rendered(size: frame.size) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        })
        viewModel.document.layers[layerIndex].image = image
        viewModel.document.layers[layerIndex].frame = frame

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        viewModel.copySelectedLayersToClipboard()

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.clipboard.action",
            arguments: ["action": .string("pasteInPlace")]
        ))

        #expect(response.ok)
        #expect(viewModel.document.selectedLayer?.frame == frame)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.clipboardPasteLayer"))
    }

    @Test func registryAppliesExplicitSelectionFeatherRadius() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.selectionModifyAmount = 1
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.selection.feather",
            arguments: ["radius": .number(3)]
        ))

        #expect(response.ok)
        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterizedMask(canvasSize: viewModel.document.canvasSize))
        #expect(maskAlpha(mask, x: 15, y: 13) == 255)
        #expect(maskAlpha(mask, x: 7, y: 13) > 0)
        #expect(maskAlpha(mask, x: 7, y: 13) < 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionFeathered", 3))
    }

    @Test func registryAppliesExplicitSelectionModifyAmount() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.selectionModifyAmount = 1
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.selection.modify",
            arguments: [
                "action": .string("border"),
                "amount": .number(2)
            ]
        ))

        #expect(response.ok)
        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterizedMask(canvasSize: viewModel.document.canvasSize))
        #expect(maskAlpha(mask, x: 8, y: 13) == 255)
        #expect(maskAlpha(mask, x: 15, y: 13) == 0)
        #expect(maskAlpha(mask, x: 21, y: 13) == 255)
        #expect(maskAlpha(mask, x: 22, y: 13) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionBordered", 2))
    }

    @Test func registryAppliesExplicitLayerTransparencyThreshold() throws {
        let size = CGSize(width: 20, height: 10)
        let viewModel = ImageEditorViewModel(
            sourceName: "automation",
            image: NSImage.transparent(size: size)
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let image = try #require(NSImage.rendered(size: size) { _ in
            NSColor(calibratedWhite: 1, alpha: 0.25).setFill()
            CGRect(x: 0, y: 0, width: 10, height: 10).fill()
            NSColor(calibratedWhite: 1, alpha: 1).setFill()
            CGRect(x: 10, y: 0, width: 10, height: 10).fill()
        })
        viewModel.document.layers[layerIndex].image = image
        viewModel.document.layers[layerIndex].frame = CGRect(origin: .zero, size: size)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.selection.modify",
            arguments: [
                "action": .string("loadTransparency"),
                "threshold": .number(200)
            ]
        ))

        #expect(response.ok)
        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterizedMask(canvasSize: size))
        #expect(maskAlpha(mask, x: 5, y: 5) == 0)
        #expect(maskAlpha(mask, x: 15, y: 5) == 255)
        #expect(selection.bounds.minX >= 10)
    }

    @Test func registryAppliesExplicitMagicWandTolerance() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let canvasSize = CGSize(width: 20, height: 10)
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 10, height: 10).fill()
            NSColor(calibratedRed: 0.8, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 10, y: 0, width: 10, height: 10).fill()
        })
        viewModel.document.layers[layerIndex].image = image
        viewModel.document.layers[layerIndex].frame = CGRect(origin: .zero, size: canvasSize)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let narrowResponse = registry.execute(request(
            operation: "call",
            name: "xomo.selection.magic",
            arguments: [
                "x": .number(3),
                "y": .number(5),
                "tolerance": .number(0.05)
            ]
        ))
        #expect(narrowResponse.ok)
        #expect(try #require(viewModel.document.selection).bounds.width == 10)

        viewModel.clearSelection()
        let broadResponse = registry.execute(request(
            operation: "call",
            name: "xomo.selection.magic",
            arguments: [
                "x": .number(3),
                "y": .number(5),
                "tolerance": .number(0.25)
            ]
        ))
        #expect(broadResponse.ok)
        #expect(try #require(viewModel.document.selection).bounds.width == 20)
    }

    @Test func registrySelectsSeparatedMagicWandMatchesWhenContiguousIsDisabled() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let canvasSize = CGSize(width: 30, height: 10)
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 10, height: 10).fill()
            NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1).setFill()
            CGRect(x: 10, y: 0, width: 10, height: 10).fill()
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 20, y: 0, width: 10, height: 10).fill()
        })
        viewModel.document.canvasSize = canvasSize
        viewModel.document.layers[layerIndex].image = image
        viewModel.document.layers[layerIndex].frame = CGRect(origin: .zero, size: canvasSize)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.selection.magic",
            arguments: [
                "x": .number(3),
                "y": .number(5),
                "tolerance": .number(0.02),
                "contiguous": .bool(false)
            ]
        ))

        #expect(response.ok)
        #expect(!viewModel.isMagicWandContiguous)
        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 5, y: 5) == 255)
        #expect(maskAlpha(mask, x: 15, y: 5) == 0)
        #expect(maskAlpha(mask, x: 25, y: 5) == 255)
    }

    @Test func registryAppliesExplicitColorRangeTolerance() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let canvasSize = CGSize(width: 20, height: 10)
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 10, height: 10).fill()
            NSColor(calibratedRed: 0.8, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 10, y: 0, width: 10, height: 10).fill()
        })
        viewModel.document.layers[layerIndex].image = image
        viewModel.document.layers[layerIndex].frame = CGRect(origin: .zero, size: canvasSize)
        viewModel.foregroundColor = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
        viewModel.tolerance = 0.05
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.selection.modify",
            arguments: [
                "action": .string("colorRange"),
                "tolerance": .number(0.25)
            ]
        ))

        #expect(response.ok)
        #expect(try #require(viewModel.document.selection).bounds.width == 20)
        #expect(viewModel.tolerance == 0.05)
    }

    @Test func registryQueuesPSDOpenThroughTheSharedCoordinator() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let data = try ImageEditorPSDCodec.encode(document: viewModel.document)
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-open-\(UUID().uuidString).psd")
        defer { try? FileManager.default.removeItem(at: path) }
        try data.write(to: path, options: .atomic)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.psd.open",
            arguments: ["path": .string(path.path)]
        ))
        #expect(response.ok)
        #expect(response.result?.objectValue?["fileName"] == .string(path.lastPathComponent))
        #expect(response.result?.objectValue?["status"] == .string("queued"))

        let rejected = registry.execute(request(
            operation: "call",
            name: "xomo.psd.open",
            arguments: ["path": .string(path.deletingPathExtension().appendingPathExtension("png").path)]
        ))
        #expect(!rejected.ok)
    }

    @Test func registrySavesCurrentDocumentAsPSDAndVerifiesIt() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-save-\(UUID().uuidString).psd")
        defer { try? FileManager.default.removeItem(at: path) }

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.psd.save",
            arguments: ["path": .string(path.path)]
        ))
        #expect(response.ok)
        #expect(response.result?.objectValue?["status"] == .string("saved"))
        #expect(response.result?.objectValue?["layerCount"] == .number(Double(viewModel.document.layers.count)))
        #expect(FileManager.default.fileExists(atPath: path.path))
        let restored = try ImageEditorPSDCodec.decode(
            Data(contentsOf: path),
            sourceName: path.lastPathComponent
        )
        #expect(restored.canvasSize == viewModel.document.canvasSize)
        #expect(restored.layers.count == viewModel.document.layers.count)
        #expect(viewModel.document.history.count == historyCount)

        let rejected = registry.execute(request(
            operation: "call",
            name: "xomo.psd.save",
            arguments: ["path": .string(path.deletingPathExtension().appendingPathExtension("png").path)]
        ))
        #expect(!rejected.ok)
    }

    @Test func registryInspectsPSDCompatibilityWithoutChangingDocument() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let documentHistoryCount = viewModel.document.history.count
        let data = try ImageEditorPSDCodec.encode(document: viewModel.document)
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-inspect-\(UUID().uuidString).psd")
        defer { try? FileManager.default.removeItem(at: path) }
        try data.write(to: path, options: .atomic)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.psd.inspect",
            arguments: ["path": .string(path.path)]
        ))
        #expect(response.ok)
        let result = try #require(response.result?.objectValue)
        #expect(result["fileName"] == .string(path.lastPathComponent))
        #expect(result["width"] == .number(320))
        #expect(result["height"] == .number(240))
        #expect(result["layerCount"] == .number(Double(viewModel.document.layers.count)))
        #expect(result["requiresAttention"] == .bool(false))
        #expect(result["compressions"]?.arrayValue?.isEmpty == false)
        #expect(viewModel.document.history.count == documentHistoryCount)

        let rejected = registry.execute(request(
            operation: "call",
            name: "xomo.psd.inspect",
            arguments: ["path": .string(path.deletingPathExtension().appendingPathExtension("png").path)]
        ))
        #expect(!rejected.ok)
    }

    @Test func registryInspectsExternalPSDFixtureAndReportsUnsupportedSemantics() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/PSD/unsupported-features.psd")
        #expect(FileManager.default.fileExists(atPath: fixtureURL.path))

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.psd.inspect",
            arguments: ["path": .string(fixtureURL.path)]
        ))
        #expect(response.ok)
        let result = try #require(response.result?.objectValue)
        #expect(result["fileName"] == .string("unsupported-features.psd"))
        #expect(result["width"] == .number(4))
        #expect(result["height"] == .number(4))
        #expect(result["layerCount"] == .number(1))
        #expect(result["requiresAttention"] == .bool(true))
        let issueKinds = Set((result["issues"]?.arrayValue ?? []).compactMap {
            $0.objectValue?["kind"]?.stringValue
        })
        #expect(issueKinds.contains("textRasterized"))
        #expect(issueKinds.contains("smartObjectRasterized"))
        #expect(issueKinds.contains("unknownBlendMode"))
    }

    @Test func registryControlsCanvasViewportWithoutAddingHistory() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.updateCanvasViewportSize(CGSize(width: 400, height: 300))
        viewModel.setZoom(2)
        viewModel.canvasOffset = CGSize(width: 18, height: -12)
        let historyCount = viewModel.document.history.count

        let nudged = registry.execute(request(
            operation: "call",
            name: "xomo.view.pan",
            arguments: ["action": .string("nudge"), "dx": .number(12), "dy": .number(8)]
        ))
        #expect(nudged.ok)
        #expect(nudged.result?.objectValue?["offset"]?.objectValue?["x"] == .number(30))
        #expect(nudged.result?.objectValue?["offset"]?.objectValue?["y"] == .number(-4))

        let centered = registry.execute(request(
            operation: "call",
            name: "xomo.view.pan",
            arguments: ["action": .string("center"), "x": .number(48), "y": .number(36)]
        ))
        #expect(centered.ok)
        #expect(centered.result?.objectValue?["action"] == .string("center"))
        #expect(viewModel.canvasOffset != CGSize(width: 30, height: -4))
        #expect(viewModel.document.history.count == historyCount)

        let reset = registry.execute(request(
            operation: "call",
            name: "xomo.view.pan",
            arguments: ["action": .string("reset")]
        ))
        #expect(reset.ok)
        #expect(viewModel.canvasOffset == .zero)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryControlsQuickMaskThroughTheSharedSelectionPath() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        viewModel.createRectSelection(from: CGPoint(x: 16, y: 16), to: CGPoint(x: 80, y: 80))

        let enabled = registry.execute(request(
            operation: "call",
            name: "xomo.selection.quick_mask",
            arguments: ["action": .string("toggle")]
        ))
        #expect(enabled.ok)
        #expect(enabled.result?.objectValue?["active"] == .bool(true))

        let configured = registry.execute(request(
            operation: "call",
            name: "xomo.selection.quick_mask",
            arguments: [
                "action": .string("setTarget"),
                "target": .string(ImageEditorQuickMaskOverlayTarget.selectedAreas.rawValue)
            ]
        ))
        #expect(configured.ok)
        #expect(configured.result?.objectValue?["target"] == .string("selectedAreas"))

        let color = XomoJSONValue.object([
            "red": .number(0.1),
            "green": .number(0.2),
            "blue": .number(0.9)
        ])
        let colorResponse = registry.execute(request(
            operation: "call",
            name: "xomo.selection.quick_mask",
            arguments: ["action": .string("setColor"), "color": color]
        ))
        #expect(colorResponse.ok)

        let opacityResponse = registry.execute(request(
            operation: "call",
            name: "xomo.selection.quick_mask",
            arguments: ["action": .string("setOpacity"), "opacity": .number(0.25)]
        ))
        #expect(opacityResponse.ok)
        #expect(opacityResponse.result?.objectValue?["opacity"] == .number(0.25))

        let paintResponse = registry.execute(request(
            operation: "call",
            name: "xomo.selection.quick_mask",
            arguments: [
                "action": .string("paint"),
                "points": .array([
                    .object(["x": .number(24), "y": .number(24)]),
                    .object(["x": .number(36), "y": .number(36)])
                ]),
                "reveal": .bool(true)
            ]
        ))
        #expect(paintResponse.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickMaskReveal"))

        let disabled = registry.execute(request(
            operation: "call",
            name: "xomo.selection.quick_mask",
            arguments: ["action": .string("toggle")]
        ))
        #expect(disabled.ok)
        #expect(disabled.result?.objectValue?["active"] == .bool(false))
    }

    @Test func registryReadsAndExportsComponentThemeTokens() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.xomoComponentTheme = .chakraUI

        let read = registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("get")]
        ))
        #expect(read.ok)
        guard case .object(let snapshot) = read.result else {
            Issue.record("Expected theme token snapshot")
            return
        }
        #expect(snapshot["theme"] == .string("chakraUI"))
        #expect(snapshot["schemaVersion"] == .number(1))
        #expect(snapshot["colors"]?.objectValue?["accent"]?.stringValue?.hasPrefix("#") == true)

        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-theme-\(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        let exported = registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("export"), "path": .string(path.path)]
        ))
        #expect(exported.ok)
        #expect(FileManager.default.fileExists(atPath: path.path))
        let exportedData = try Data(contentsOf: path)
        let exportedSnapshot = try JSONDecoder().decode(XomoComponentThemeTokenSnapshot.self, from: exportedData)
        #expect(exportedSnapshot == .init(theme: .chakraUI, tokens: XomoComponentTheme.chakraUI.tokens))
    }

    @Test func registryValidatesAndCanonicalizesFigmaLinksWithoutNetworkAccess() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.figma.link",
            arguments: [
                "url": .string("https://www.figma.com/design/abc123DEF456/Checkout?node-id=32-9&token=must-not-persist")
            ]
        ))
        #expect(response.ok)
        let result = try #require(response.result?.objectValue)
        #expect(result["resourceType"] == .string("design"))
        #expect(result["fileKey"] == .string("abc123DEF456"))
        #expect(result["nodeId"] == .string("32:9"))
        #expect(result["plannedImportScope"] == .string("designDocument"))
        #expect(result["discardedQueryItemCount"] == .number(1))
        #expect(result["canonicalUrl"]?.stringValue?.contains("token") == false)

        let rejected = registry.execute(request(
            operation: "call",
            name: "xomo.figma.link",
            arguments: ["url": .string("http://www.figma.com/design/abc123DEF456/Checkout")]
        ))
        #expect(!rejected.ok)
        #expect(rejected.error?.contains("xomo.figma.error.insecureScheme") == true)
    }

    @Test func registrySelectsCanvasComponentsAndDeepChildrenByVisiblePoint() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let objectFrame = try #require(viewModel.selectedXomoObjectFrame)
        let childIDs = Set(viewModel.document.layers.filter { $0.groupID == group.id }.map(\.id))
        let historyCount = viewModel.document.history.count
        viewModel.clearLayerSelection()

        let selectedObject = registry.execute(request(
            operation: "call",
            name: "xomo.object.select_at",
            arguments: ["x": .number(160), "y": .number(112)]
        ))

        #expect(selectedObject.ok)
        #expect(selectedObject.result?.objectValue?["hit"] == .bool(true))
        #expect(selectedObject.result?.objectValue?["mode"] == .string("auto"))
        #expect(selectedObject.result?.objectValue?["selectedLayerId"] == .string(group.id.uuidString))
        #expect(selectedObject.result?.objectValue?["kind"] == .string("group"))
        #expect(selectedObject.result?.objectValue?["component"] == .string("button"))
        #expect(selectedObject.result?.objectValue?["bounds"] == .object([
            "x": .number(objectFrame.minX),
            "y": .number(objectFrame.minY),
            "width": .number(objectFrame.width),
            "height": .number(objectFrame.height)
        ]))
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.history.count == historyCount)

        let selectedChild = registry.execute(request(
            operation: "call",
            name: "xomo.object.select_at",
            arguments: [
                "x": .number(160),
                "y": .number(112),
                "mode": .string("deep")
            ]
        ))

        #expect(selectedChild.ok)
        let selectedChildID = try #require(viewModel.document.selectedLayerID)
        #expect(childIDs.contains(selectedChildID))
        #expect(selectedChild.result?.objectValue?["selectedLayerId"] == .string(selectedChildID.uuidString))
        #expect(selectedChild.result?.objectValue?["component"] == .null)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryObjectPointSelectionCanClearOnMissAndRejectUnknownDepth() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let historyCount = viewModel.document.history.count

        let miss = registry.execute(request(
            operation: "call",
            name: "xomo.object.select_at",
            arguments: [
                "x": .number(-10),
                "y": .number(-10),
                "clearOnMiss": .bool(true)
            ]
        ))

        #expect(miss.ok)
        #expect(miss.result?.objectValue?["hit"] == .bool(false))
        #expect(miss.result?.objectValue?["selectedLayerId"] == .null)
        #expect(viewModel.document.selectedLayerID == nil)
        #expect(viewModel.document.selectedLayerIDs.isEmpty)
        #expect(viewModel.document.history.count == historyCount)

        let rejected = registry.execute(request(
            operation: "call",
            name: "xomo.object.select_at",
            arguments: [
                "x": .number(160),
                "y": .number(112),
                "mode": .string("mystery")
            ]
        ))
        #expect(!rejected.ok)
        #expect(rejected.error?.contains("Unknown object selection mode") == true)
    }

    @Test func registryReportsMultiObjectBoundsAndLiveMovePreview() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        viewModel.insertXomoComponent(.button, at: CGPoint(x: 60, y: 80))
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstFrame = try #require(viewModel.selectedXomoObjectFrame)
        viewModel.insertXomoComponent(.avatar, at: CGPoint(x: 220, y: 140))
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondFrame = try #require(viewModel.selectedXomoObjectFrame)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        let expectedBounds = firstFrame.union(secondFrame)
        let historyCount = viewModel.document.history.count

        let initial = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))

        #expect(initial.ok)
        #expect(initial.result?.objectValue?["active"] == .bool(true))
        #expect(initial.result?.objectValue?["preview"] == .bool(false))
        #expect(initial.result?.objectValue?["operation"] == nil)
        #expect(initial.result?.objectValue?["originalBounds"] == nil)
        #expect(initial.result?.objectValue?["delta"] == nil)
        #expect(initial.result?.objectValue?["selectedCount"] == .number(2))
        #expect(initial.result?.objectValue?["selectedLayerIds"]?.arrayValue == [
            firstID.uuidString,
            secondID.uuidString
        ].sorted().map(XomoJSONValue.string))
        #expect(initial.result?.objectValue?["bounds"] == .object([
            "x": .number(expectedBounds.minX),
            "y": .number(expectedBounds.minY),
            "width": .number(expectedBounds.width),
            "height": .number(expectedBounds.height)
        ]))
        #expect(viewModel.selectedObjectBoundsInfoText.contains("2"))
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 13.5, height: -7.5))
        let preview = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))

        #expect(preview.ok)
        #expect(preview.result?.objectValue?["preview"] == .bool(true))
        #expect(preview.result?.objectValue?["operation"] == .string("move"))
        #expect(
            preview.result?.objectValue?["originalBounds"]
                == initial.result?.objectValue?["bounds"]
        )
        #expect(preview.result?.objectValue?["delta"] == .object([
            "x": .number(13.5),
            "y": .number(-7.5)
        ]))
        #expect(preview.result?.objectValue?["sizeDelta"] == nil)
        #expect(preview.result?.objectValue?["scalePercent"] == nil)
        #expect(
            preview.result?.objectValue?["bounds"]?.objectValue?["x"]
                == .number(expectedBounds.minX + 13.5)
        )
        #expect(
            preview.result?.objectValue?["bounds"]?.objectValue?["y"]
                == .number(expectedBounds.minY - 7.5)
        )
        #expect(viewModel.selectedObjectBoundsInfoText.contains("ΔX"))
        #expect(viewModel.selectedObjectBoundsInfoText.contains("ΔY"))
        #expect(viewModel.selectedObjectBoundsInfoText.contains(".5"))
        #expect(viewModel.movingObjectPreviewDelta == CGSize(width: 13.5, height: -7.5))
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.cancelMovingSelectedLayer())
        let restored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))
        #expect(restored.result?.objectValue?["preview"] == .bool(false))
        #expect(restored.result?.objectValue?["operation"] == nil)
        #expect(restored.result?.objectValue?["originalBounds"] == nil)
        #expect(restored.result?.objectValue?["delta"] == nil)
        #expect(restored.result?.objectValue?["bounds"] == initial.result?.objectValue?["bounds"])
        #expect(viewModel.movingObjectPreviewDelta == nil)
        #expect(viewModel.document.history.count == historyCount)

        viewModel.clearLayerSelection()
        let empty = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))
        #expect(empty.result?.objectValue?["active"] == .bool(false))
        #expect(empty.result?.objectValue?["selectedCount"] == .number(0))
        #expect(viewModel.selectedObjectBoundsInfoText.contains("—"))
    }

    @Test func registryReportsResizeAndRotationPreviewContext() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        viewModel.textValue = "Transform"
        viewModel.textSize = 28
        viewModel.addText(at: CGPoint(x: 80, y: 90))
        let originalFrame = try #require(viewModel.selectedLayerTransformFrame)
        let historyCount = viewModel.document.history.count
        let center = CGPoint(x: originalFrame.midX, y: originalFrame.midY)
        let radius: CGFloat = 80
        let start = CGPoint(x: center.x, y: center.y + radius)
        let dragAngle = CGFloat(104) * .pi / 180
        let end = CGPoint(
            x: center.x + cos(dragAngle) * radius,
            y: center.y + sin(dragAngle) * radius
        )

        viewModel.beginRotatingSelectedLayer(from: start)
        viewModel.rotateSelectedLayer(to: end, snappingToStep: true)
        let rotation = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))

        #expect(rotation.ok)
        #expect(rotation.result?.objectValue?["preview"] == .bool(true))
        #expect(rotation.result?.objectValue?["operation"] == .string("rotate"))
        #expect(rotation.result?.objectValue?["originalBounds"] == .object([
            "x": .number(originalFrame.minX),
            "y": .number(originalFrame.minY),
            "width": .number(originalFrame.width),
            "height": .number(originalFrame.height)
        ]))
        #expect(rotation.result?.objectValue?["rotationDeltaDegrees"] == .number(15))
        #expect(rotation.result?.objectValue?["delta"] == nil)
        #expect(rotation.result?.objectValue?["sizeDelta"] == nil)
        #expect(rotation.result?.objectValue?["scalePercent"] == nil)
        #expect(viewModel.selectedObjectBoundsInfoText.contains("Δθ"))
        #expect(viewModel.selectedObjectBoundsInfoText.contains("15°"))
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(viewModel.selectedLayerTransformFrame == originalFrame)
        let restoredAfterRotation = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))
        #expect(restoredAfterRotation.result?.objectValue?["preview"] == .bool(false))
        #expect(restoredAfterRotation.result?.objectValue?["operation"] == nil)
        #expect(restoredAfterRotation.result?.objectValue?["originalBounds"] == nil)
        #expect(restoredAfterRotation.result?.objectValue?["rotationDeltaDegrees"] == nil)
        #expect(viewModel.document.history.count == historyCount)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 20, y: originalFrame.midY),
            handle: .right
        )
        let resize = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))

        #expect(resize.ok)
        #expect(resize.result?.objectValue?["preview"] == .bool(true))
        #expect(resize.result?.objectValue?["operation"] == .string("resize"))
        #expect(resize.result?.objectValue?["originalBounds"] == .object([
            "x": .number(originalFrame.minX),
            "y": .number(originalFrame.minY),
            "width": .number(originalFrame.width),
            "height": .number(originalFrame.height)
        ]))
        #expect(resize.result?.objectValue?["delta"] == nil)
        #expect(resize.result?.objectValue?["rotationDeltaDegrees"] == nil)
        let resizedFrame = try #require(viewModel.selectedLayerTransformFrame)
        #expect(resizedFrame.width > originalFrame.width)
        #expect(resize.result?.objectValue?["sizeDelta"] == .object([
            "width": .number(resizedFrame.width - originalFrame.width),
            "height": .number(resizedFrame.height - originalFrame.height)
        ]))
        #expect(resize.result?.objectValue?["scalePercent"] == .object([
            "width": .number(resizedFrame.width / originalFrame.width * 100),
            "height": .number(resizedFrame.height / originalFrame.height * 100)
        ]))
        #expect(
            resize.result?.objectValue?["bounds"]?.objectValue?["width"]
                == .number(resizedFrame.width)
        )
        #expect(viewModel.selectedObjectBoundsInfoText.contains("ΔW"))
        #expect(viewModel.selectedObjectBoundsInfoText.contains("ΔH"))
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(viewModel.selectedLayerTransformFrame == originalFrame)
        #expect(viewModel.resizingObjectPreviewDelta == nil)
        #expect(viewModel.resizingObjectPreviewScalePercent == nil)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryReportsDefaultAndCustomTransformReferencePoint() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        viewModel.insertXomoComponent(.button, at: CGPoint(x: 120, y: 90))
        let frame = try #require(viewModel.selectedXomoObjectFrame)
        let historyCount = viewModel.document.history.count

        let initial = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))

        #expect(initial.ok)
        #expect(initial.result?.objectValue?["referencePoint"] == .object([
            "x": .number(frame.midX),
            "y": .number(frame.midY),
            "custom": .bool(false)
        ]))

        let customPoint = CGPoint(x: frame.minX - 14, y: frame.maxY + 9)
        viewModel.setSelectedLayerTransformReferencePoint(customPoint)
        let custom = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))

        #expect(custom.ok)
        #expect(custom.result?.objectValue?["referencePoint"] == .object([
            "x": .number(customPoint.x),
            "y": .number(customPoint.y),
            "custom": .bool(true)
        ]))
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.resetSelectedLayerTransformReferencePoint())
        let restored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))
        #expect(restored.result?.objectValue?["referencePoint"] == initial.result?.objectValue?["referencePoint"])
        #expect(viewModel.document.history.count == historyCount)

        viewModel.clearLayerSelection()
        let empty = registry.execute(request(
            operation: "call",
            name: "xomo.layer.selection_bounds"
        ))
        #expect(empty.result?.objectValue?["active"] == .bool(false))
        #expect(empty.result?.objectValue?["referencePoint"] == nil)
    }

    @Test func registrySetsAndResetsTransformReferencePointWithoutHistory() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        viewModel.insertXomoComponent(.button, at: CGPoint(x: 140, y: 110))
        let frame = try #require(viewModel.selectedXomoObjectFrame)
        let historyCount = viewModel.document.history.count
        let point = CGPoint(x: frame.maxX + 18, y: frame.minY - 12)

        let set = registry.execute(request(
            operation: "call",
            name: "xomo.layer.transform_reference",
            arguments: [
                "action": .string("set"),
                "x": .number(point.x),
                "y": .number(point.y)
            ]
        ))

        #expect(set.ok)
        #expect(set.result?.objectValue?["changed"] == .bool(true))
        #expect(set.result?.objectValue?["referencePoint"] == .object([
            "x": .number(point.x),
            "y": .number(point.y),
            "custom": .bool(true)
        ]))
        #expect(viewModel.document.history.count == historyCount)

        let unchanged = registry.execute(request(
            operation: "call",
            name: "xomo.layer.transform_reference",
            arguments: [
                "action": .string("set"),
                "x": .number(point.x),
                "y": .number(point.y)
            ]
        ))
        #expect(unchanged.ok)
        #expect(unchanged.result?.objectValue?["changed"] == .bool(false))

        let reset = registry.execute(request(
            operation: "call",
            name: "xomo.layer.transform_reference",
            arguments: ["action": .string("reset")]
        ))
        #expect(reset.ok)
        #expect(reset.result?.objectValue?["changed"] == .bool(true))
        #expect(reset.result?.objectValue?["referencePoint"] == .object([
            "x": .number(frame.midX),
            "y": .number(frame.midY),
            "custom": .bool(false)
        ]))
        #expect(viewModel.document.history.count == historyCount)

        let alreadyReset = registry.execute(request(
            operation: "call",
            name: "xomo.layer.transform_reference",
            arguments: ["action": .string("reset")]
        ))
        #expect(alreadyReset.ok)
        #expect(alreadyReset.result?.objectValue?["changed"] == .bool(false))

        let unknownAction = registry.execute(request(
            operation: "call",
            name: "xomo.layer.transform_reference",
            arguments: ["action": .string("unexpected")]
        ))
        #expect(!unknownAction.ok)
        #expect(viewModel.document.history.count == historyCount)

        viewModel.clearLayerSelection()
        let missingSelection = registry.execute(request(
            operation: "call",
            name: "xomo.layer.transform_reference",
            arguments: [
                "action": .string("set"),
                "x": .number(10),
                "y": .number(20)
            ]
        ))
        #expect(!missingSelection.ok)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryImportsLocalComponentTokensForSubsequentInsertion() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        var colors = XomoComponentTheme.native.tokenSnapshot.colors
        colors["accent"] = "#801F4FFF"
        let snapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: colors,
            metrics: XomoComponentTheme.native.tokenSnapshot.metrics
        )
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-automation-token-\(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        try Data(snapshot.encodedJSON().utf8).write(to: path)

        let imported = registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("import"), "path": .string(path.path)]
        ))
        #expect(imported.ok)
        #expect(viewModel.hasLocalXomoThemeTokens)

        let inserted = registry.execute(request(
            operation: "call",
            name: "xomo.component.insert",
            arguments: ["component": .string("button")]
        ))
        #expect(inserted.ok)
        let group = try #require(viewModel.document.selectedLayer)
        let background = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isShape })
        #expect(background.shapeContent?.fillColor.isEqual(NSColor(deviceRed: 0x80 / 255, green: 0x1F / 255, blue: 0x4F / 255, alpha: 1)) == true)
        #expect(group.xomoComponentInstance?.tokenSnapshot == snapshot)
    }

    @Test func registryAppliesActiveComponentTokensToSelectedComponent() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.insertXomoComponent(.button)
        viewModel.xomoComponentTheme = .chakraUI

        let applied = registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("apply")]
        ))
        #expect(applied.ok)
        guard case .object(let result) = applied.result else {
            Issue.record("Expected applied token snapshot")
            return
        }
        #expect(result["action"] == .string("apply"))
        #expect(result["theme"] == .string("chakraUI"))
        #expect(viewModel.document.selectedLayer?.xomoComponentInstance?.theme == .chakraUI)
        #expect(viewModel.document.history.last?.title == L10n.text("xomo.theme.history.apply"))
    }

    @Test func registryClearsImportedComponentTokensAndKeepsUndoAvailable() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        var colors = XomoComponentTheme.native.tokenSnapshot.colors
        colors["accent"] = "#801F4FFF"
        let snapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: colors,
            metrics: XomoComponentTheme.native.tokenSnapshot.metrics
        )
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-automation-clear-(UUID().uuidString).xomotokens.json")
        defer { try? FileManager.default.removeItem(at: path) }
        try Data(snapshot.encodedJSON().utf8).write(to: path)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("import"), "path": .string(path.path)]
        )).ok)
        let cleared = registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("clear")]
        ))
        #expect(cleared.ok)
        #expect(viewModel.hasLocalXomoThemeTokens == false)
        #expect(viewModel.document.history.last?.title == L10n.text("xomo.theme.history.tokensCleared"))
        viewModel.undo()
        #expect(viewModel.hasLocalXomoThemeTokens)
    }

    @Test func registryRefreshesAllMappedComponentTokensAndReturnsCount() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        var firstColors = XomoComponentTheme.native.tokenSnapshot.colors
        firstColors["accent"] = "#801F4FFF"
        let firstSnapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand",
            librarySource: "local",
            colors: firstColors,
            metrics: XomoComponentTheme.native.tokenSnapshot.metrics
        )
        var secondColors = firstColors
        secondColors["accent"] = "#1D4ED8FF"
        let secondSnapshot = XomoComponentThemeTokenSnapshot(
            schemaVersion: 1,
            theme: "local-brand-v2",
            librarySource: "local",
            colors: secondColors,
            metrics: XomoComponentTheme.native.tokenSnapshot.metrics
        )
        let firstPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-automation-refresh-a-\(UUID().uuidString).xomotokens.json")
        let secondPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-automation-refresh-b-\(UUID().uuidString).xomotokens.json")
        defer {
            try? FileManager.default.removeItem(at: firstPath)
            try? FileManager.default.removeItem(at: secondPath)
        }
        try Data(firstSnapshot.encodedJSON().utf8).write(to: firstPath)
        try Data(secondSnapshot.encodedJSON().utf8).write(to: secondPath)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("import"), "path": .string(firstPath.path)]
        )).ok)
        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.component.insert",
            arguments: ["component": .string("button")]
        )).ok)
        let group = try #require(viewModel.document.selectedLayer)
        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("import"), "path": .string(secondPath.path)]
        )).ok)

        let refreshed = registry.execute(request(
            operation: "call",
            name: "xomo.component.tokens",
            arguments: ["action": .string("refresh")]
        ))
        #expect(refreshed.ok)
        guard case .object(let result) = refreshed.result else {
            Issue.record("Expected refresh result")
            return
        }
        #expect(result["action"] == .string("refresh"))
        #expect(result["count"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == group.id }?.xomoComponentInstance?.tokenSnapshot == secondSnapshot)
        #expect(viewModel.document.history.last?.title == L10n.format("xomo.theme.history.tokensRefreshed", 1))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == group.id }?.xomoComponentInstance?.tokenSnapshot == firstSnapshot)
    }

    @Test func registryLayerListExposesFigmaVariableBindings() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.addText(at: CGPoint(x: 24, y: 32))
        let layerIndex = try #require(viewModel.document.layers.indices.last)
        let layerID = viewModel.document.layers[layerIndex].id
        viewModel.document.layers[layerIndex].xomoFigmaVariableBindings = [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-primary"),
            XomoFigmaVariableBinding(field: "characters", variableID: "VariableID:body-font")
        ]
        viewModel.document.layers[layerIndex].xomoFigmaImageFill = XomoFigmaImageFillMetadata(
            imageReference: "img-ref-hero",
            scaleMode: "CROP",
            imageTransform: XomoFigmaPlanTransform([[1, 0, 0.1], [0, 1, 0.2]]),
            scalingFactor: 1.5,
            rotation: 90,
            filters: XomoFigmaPlanImageFilters(exposure: 0.25)
        )
        viewModel.document.layers[layerIndex].xomoFigmaSourceID = "12:34"
        viewModel.document.layers[layerIndex].xomoFigmaSourceURL = URL(
            string: "https://www.figma.com/design/abc123/Checkout?node-id=12-34"
        )
        viewModel.document.layers[layerIndex].xomoFigmaNodeType = "TEXT"
        viewModel.document.layers[layerIndex].xomoFigmaComponentRole = .instance
        viewModel.document.layers[layerIndex].xomoFigmaSizeConstraints = XomoFigmaSizeConstraints(
            minWidth: 240,
            maxWidth: 200,
            minHeight: nil,
            maxHeight: 120
        )
        viewModel.document.layers[layerIndex].xomoFigmaSizeConstraintDefaults = XomoFigmaSizeConstraints(
            minWidth: 40,
            maxWidth: 200,
            minHeight: nil,
            maxHeight: 120
        )

        let listed = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list"
        ))
        #expect(listed.ok)
        guard case .array(let layers) = listed.result,
              let layer = layers.first(where: { $0.objectValue?["id"] == .string(layerID.uuidString) })?.objectValue
        else {
            Issue.record("Expected the created text layer in layer list")
            return
        }
        #expect(layer["figmaVariableBindingCount"] == .number(2))
        #expect(layer["figmaVariableBindings"]?.arrayValue == [
            .object([
                "id": .string("fills:VariableID:brand-primary"),
                "field": .string("fills"),
                "variableId": .string("VariableID:brand-primary")
            ]),
            .object([
                "id": .string("characters:VariableID:body-font"),
                "field": .string("characters"),
                "variableId": .string("VariableID:body-font")
            ])
        ])
        #expect(layer["figmaImageFill"]?.objectValue?["imageReference"] == .string("img-ref-hero"))
        #expect(layer["figmaImageFill"]?.objectValue?["scaleMode"] == .string("CROP"))
        #expect(layer["figmaImageFill"]?.objectValue?["rotation"] == .number(90))
        #expect(layer["figmaImageFill"]?.objectValue?["filters"]?.objectValue?["exposure"] == .number(0.25))
        #expect(layer["figmaSizeConstraints"]?.objectValue?["current"]?.objectValue?["minWidth"] == .number(240))
        #expect(layer["figmaSizeConstraints"]?.objectValue?["importedDefaults"]?.objectValue?["minWidth"] == .number(40))
        #expect(layer["figmaSizeConstraints"]?.objectValue?["hasOverrides"] == .bool(true))
        #expect(layer["figmaSizeConstraints"]?.objectValue?["hasConflicts"] == .bool(true))
        #expect(layer["figmaSizeConstraints"]?.objectValue?["conflicts"] == .array([.string("width")]))
        #expect(layer["figmaSource"]?.objectValue?["id"] == .string("12:34"))
        #expect(layer["figmaSource"]?.objectValue?["fileKey"] == .string("abc123"))
        #expect(layer["figmaSource"]?.objectValue?["resourceType"] == .string("design"))
        #expect(layer["figmaSource"]?.objectValue?["importScope"] == .string("designDocument"))
        #expect(layer["figmaSource"]?.objectValue?["url"] == .string(
            "https://www.figma.com/design/abc123/Checkout?node-id=12-34"
        ))
        #expect(layer["figmaSource"]?.objectValue?["nodeType"] == .string("TEXT"))
        #expect(layer["figmaSource"]?.objectValue?["componentRole"] == .string("INSTANCE"))

        let bound = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaBindings": .string("bound")]
        ))
        #expect(bound.ok)
        #expect(bound.result?.arrayValue?.count == 1)
        #expect(bound.result?.arrayValue?.first?.objectValue?["id"] == .string(layerID.uuidString))

        let unbound = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaBindings": .string("unbound")]
        ))
        #expect(unbound.ok)
        #expect(unbound.result?.arrayValue?.contains {
            $0.objectValue?["id"] == .string(layerID.uuidString)
        } == false)

        for constraintFilter in ["constrained", "overridden", "conflicted"] {
            let filtered = registry.execute(request(
                operation: "call",
                name: "xomo.layer.list",
                arguments: ["figmaConstraints": .string(constraintFilter)]
            ))
            #expect(filtered.ok)
            #expect(filtered.result?.arrayValue?.count == 1)
            #expect(filtered.result?.arrayValue?.first?.objectValue?["id"] == .string(layerID.uuidString))
        }

        let imported = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: [
                "figmaSource": .string("imported"),
                "figmaConstraints": .string("conflicted")
            ]
        ))
        #expect(imported.ok)
        #expect(imported.result?.arrayValue?.count == 1)
        #expect(imported.result?.arrayValue?.first?.objectValue?["id"] == .string(layerID.uuidString))

        let figmaTextInstance = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: [
                "figmaNodeType": .string(" text "),
                "figmaNodeId": .string(" 12-34 "),
                "figmaFileKey": .string(" abc123 "),
                "figmaResourceType": .string("design"),
                "figmaImportScope": .string("designDocument"),
                "figmaComponentRole": .string("INSTANCE"),
                "figmaSource": .string("imported"),
                "figmaConstraints": .string("conflicted")
            ]
        ))
        #expect(figmaTextInstance.ok)
        #expect(figmaTextInstance.result?.arrayValue?.count == 1)
        #expect(figmaTextInstance.result?.arrayValue?.first?.objectValue?["id"] == .string(layerID.uuidString))

        let missingNodeID = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaNodeId": .string("12:35")]
        ))
        #expect(missingNodeID.ok)
        #expect(missingNodeID.result?.arrayValue?.isEmpty == true)

        let missingFileKey = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: [
                "figmaFileKey": .string("otherFile"),
                "figmaNodeId": .string("12:34")
            ]
        ))
        #expect(missingFileKey.ok)
        #expect(missingFileKey.result?.arrayValue?.isEmpty == true)

        let wrongResourceType = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: [
                "figmaResourceType": .string("board"),
                "figmaFileKey": .string("abc123")
            ]
        ))
        #expect(wrongResourceType.ok)
        #expect(wrongResourceType.result?.arrayValue?.isEmpty == true)

        let wrongImportScope = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: [
                "figmaImportScope": .string("figJamBoard"),
                "figmaResourceType": .string("design")
            ]
        ))
        #expect(wrongImportScope.ok)
        #expect(wrongImportScope.result?.arrayValue?.isEmpty == true)

        let componentsOnly = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaComponentRole": .string("COMPONENT")]
        ))
        #expect(componentsOnly.ok)
        #expect(componentsOnly.result?.arrayValue?.isEmpty == true)

        let nonComponents = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaComponentRole": .string("none")]
        ))
        #expect(nonComponents.ok)
        #expect(nonComponents.result?.arrayValue?.contains {
            $0.objectValue?["id"] == .string(layerID.uuidString)
        } == false)

        let local = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaSource": .string("local")]
        ))
        #expect(local.ok)
        #expect(local.result?.arrayValue?.contains {
            $0.objectValue?["id"] == .string(layerID.uuidString)
        } == false)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaBindings": .string("linked")]
        ))
        #expect(!invalid.ok)
        let invalidConstraints = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaConstraints": .string("invalid")]
        ))
        #expect(!invalidConstraints.ok)
        let invalidSource = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaSource": .string("remote")]
        ))
        #expect(!invalidSource.ok)
        let invalidNodeType = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaNodeType": .string("  ")]
        ))
        #expect(!invalidNodeType.ok)
        let invalidNodeID = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaNodeId": .string("  ")]
        ))
        #expect(!invalidNodeID.ok)
        let invalidNodeIDType = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaNodeId": .number(12)]
        ))
        #expect(!invalidNodeIDType.ok)
        let invalidFileKey = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaFileKey": .string("  ")]
        ))
        #expect(!invalidFileKey.ok)
        let invalidFileKeyType = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaFileKey": .bool(true)]
        ))
        #expect(!invalidFileKeyType.ok)
        let invalidResourceType = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaResourceType": .string("canvas")]
        ))
        #expect(!invalidResourceType.ok)
        let invalidResourceTypeValue = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaResourceType": .number(1)]
        ))
        #expect(!invalidResourceTypeValue.ok)
        let invalidImportScope = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaImportScope": .string("editable")]
        ))
        #expect(!invalidImportScope.ok)
        let invalidImportScopeValue = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaImportScope": .bool(false)]
        ))
        #expect(!invalidImportScopeValue.ok)
        let invalidComponentRole = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaComponentRole": .string("FRAME")]
        ))
        #expect(!invalidComponentRole.ok)
        let invalidComponentRoleType = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaComponentRole": .number(1)]
        ))
        #expect(!invalidComponentRoleType.ok)
    }

    @Test func registryListsAndCopiesFigmaBindingsFromSelectedLayers() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let firstID = try #require(viewModel.document.layers.first?.id)
        var second = ImageEditorLayer.blank(name: "Second", size: viewModel.document.canvasSize)
        second.xomoFigmaVariableBindings = [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-primary"),
            XomoFigmaVariableBinding(field: "characters", variableID: "VariableID:label")
        ]
        viewModel.document.layers.append(second)
        viewModel.document.layers[0].xomoFigmaVariableBindings = [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-primary")
        ]
        viewModel.document.selectedLayerID = second.id
        viewModel.document.selectedLayerIDs = [firstID, second.id]

        let listed = registry.execute(request(
            operation: "call",
            name: "xomo.figma.bindings",
            arguments: ["action": .string("list")]
        ))
        #expect(listed.ok)
        #expect(listed.result?.objectValue?["count"] == .number(2))
        #expect(listed.result?.objectValue?["variableIds"] == .array([
            .string("VariableID:brand-primary"),
            .string("VariableID:label")
        ]))

        let copied = registry.execute(request(
            operation: "call",
            name: "xomo.figma.bindings",
            arguments: ["action": .string("copy")]
        ))
        #expect(copied.ok)
        #expect(NSPasteboard.general.string(forType: .string) == "VariableID:brand-primary\nVariableID:label")
    }

    @Test func registryListsSetsAndResetsFigmaComponentProperties() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue"),
            "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        ]
        viewModel.document.layers[layerIndex].xomoFigmaComponentPropertyDefaults =
            viewModel.document.layers[layerIndex].xomoFigmaComponentProperties

        let listed = registry.execute(request(
            operation: "call",
            name: "xomo.figma.component_properties",
            arguments: ["action": .string("list")]
        ))
        #expect(listed.ok)
        #expect(listed.result?.objectValue?["layerId"] == .string(layerID.uuidString))
        #expect(listed.result?.objectValue?["properties"]?.objectValue?["Label"]?.objectValue?["overridden"] == .bool(false))

        let set = registry.execute(request(
            operation: "call",
            name: "xomo.figma.component_properties",
            arguments: [
                "action": .string("set"),
                "key": .string("Label"),
                "value": .string("Buy now")
            ]
        ))
        #expect(set.ok)
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Buy now")
        #expect(set.result?.objectValue?["properties"]?.objectValue?["Label"]?.objectValue?["overridden"] == .bool(true))

        let cleared = registry.execute(request(
            operation: "call",
            name: "xomo.figma.component_properties",
            arguments: [
                "action": .string("set"),
                "key": .string("Label"),
                "value": .string("")
            ]
        ))
        #expect(cleared.ok)
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "")

        let reset = registry.execute(request(
            operation: "call",
            name: "xomo.figma.component_properties",
            arguments: ["action": .string("reset"), "key": .string("Label")]
        ))
        #expect(reset.ok)
        #expect(viewModel.document.selectedLayer?.xomoFigmaComponentProperties["Label"]?.value == "Continue")
        #expect(viewModel.document.history.last?.title == L10n.format("imageEditor.history.figmaComponentPropertyChanged", "Label"))
    }

    @Test func registryListsEditsAndRestoresFigmaSizeConstraints() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let imported = XomoFigmaSizeConstraints(
            minWidth: 40,
            maxWidth: 200,
            minHeight: nil,
            maxHeight: 120
        )
        viewModel.document.layers[layerIndex].xomoFigmaSourceID = "12:34"
        viewModel.document.layers[layerIndex].xomoFigmaSizeConstraints = imported
        viewModel.document.layers[layerIndex].xomoFigmaSizeConstraintDefaults = imported

        let listed = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: ["action": .string("list")]
        ))
        #expect(listed.ok)
        #expect(listed.result?.objectValue?["layerId"] == .string(layerID.uuidString))
        #expect(listed.result?.objectValue?["current"]?.objectValue?["minWidth"] == .number(40))
        #expect(listed.result?.objectValue?["importedDefaults"]?.objectValue?["maxWidth"] == .number(200))
        #expect(listed.result?.objectValue?["hasOverrides"] == .bool(false))

        let set = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("set"),
                "field": .string("minWidth"),
                "value": .number(240)
            ]
        ))
        #expect(set.ok)
        #expect(set.result?.objectValue?["current"]?.objectValue?["minWidth"] == .number(240))
        #expect(set.result?.objectValue?["overrides"]?.objectValue?["minWidth"] == .bool(true))
        #expect(set.result?.objectValue?["hasConflicts"] == .bool(true))
        #expect(set.result?.objectValue?["conflicts"] == .array([.string("width")]))

        let resolved = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("resolve"),
                "axis": .string("width")
            ]
        ))
        #expect(resolved.ok)
        #expect(resolved.result?.objectValue?["current"]?.objectValue?["maxWidth"] == .number(240))
        #expect(resolved.result?.objectValue?["hasConflicts"] == .bool(false))

        let conflictedAgain = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("set"),
                "field": .string("maxWidth"),
                "value": .number(200)
            ]
        ))
        #expect(conflictedAgain.result?.objectValue?["hasConflicts"] == .bool(true))

        let heightConflict = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("set"),
                "field": .string("minHeight"),
                "value": .number(160)
            ]
        ))
        #expect(heightConflict.result?.objectValue?["conflicts"] == .array([
            .string("width"), .string("height")
        ]))

        let resolvedAll = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: ["action": .string("resolveAll")]
        ))
        #expect(resolvedAll.ok)
        #expect(resolvedAll.result?.objectValue?["current"]?.objectValue?["maxWidth"] == .number(240))
        #expect(resolvedAll.result?.objectValue?["current"]?.objectValue?["maxHeight"] == .number(160))
        #expect(resolvedAll.result?.objectValue?["hasConflicts"] == .bool(false))

        _ = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("set"),
                "field": .string("maxWidth"),
                "value": .number(200)
            ]
        ))

        let cleared = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("clear"),
                "field": .string("maxWidth")
            ]
        ))
        #expect(cleared.ok)
        #expect(cleared.result?.objectValue?["current"]?.objectValue?["maxWidth"] == .null)
        #expect(cleared.result?.objectValue?["hasConflicts"] == .bool(false))

        let reset = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: [
                "action": .string("reset"),
                "field": .string("maxWidth")
            ]
        ))
        #expect(reset.ok)
        #expect(reset.result?.objectValue?["current"]?.objectValue?["maxWidth"] == .number(200))

        let resetAll = registry.execute(request(
            operation: "call",
            name: "xomo.figma.size_constraints",
            arguments: ["action": .string("resetAll")]
        ))
        #expect(resetAll.ok)
        #expect(resetAll.result?.objectValue?["current"]?.objectValue?["minWidth"] == .number(40))
        #expect(resetAll.result?.objectValue?["hasOverrides"] == .bool(false))
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.figmaSizeConstraintsReset"
        ))
    }

    @Test func registryManagesComponentMastersAndInstances() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 40))
        let masterID = try #require(viewModel.document.selectedLayerID)
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 360, y: 40))
        let instanceID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(masterID)
        let madeMaster = registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("makeMaster")]
        ))
        #expect(madeMaster.ok)
        #expect(madeMaster.result?.objectValue?["activeMasterId"] == .string(masterID.uuidString))
        #expect(viewModel.document.layers.first { $0.id == masterID }?.xomoComponentInstance?.masterID == masterID)

        viewModel.document.selectedLayerID = instanceID
        viewModel.document.selectedLayerIDs = [masterID, instanceID]
        let linked = registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("link")]
        ))
        #expect(linked.ok)
        #expect(viewModel.document.layers.first { $0.id == instanceID }?.xomoComponentInstance?.masterID == masterID)

        viewModel.selectLayer(masterID)
        viewModel.selectXomoComponentTheme(.chakraUI)
        viewModel.applyXomoThemeToSelectedComponent()
        viewModel.selectLayer(instanceID)
        let synced = registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("sync")]
        ))
        #expect(synced.ok)
        #expect(viewModel.document.layers.first { $0.id == instanceID }?.xomoComponentInstance?.theme == .chakraUI)

        let detached = registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("detach")]
        ))
        #expect(detached.ok)
        #expect(viewModel.document.layers.first { $0.id == instanceID }?.xomoComponentInstance?.masterID == nil)
        #expect(viewModel.document.history.last?.title == L10n.text("xomo.instance.history.detach"))
    }

    @Test func registryRejectsInvalidComponentInstanceActions() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        #expect(!registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("makeMaster")]
        )).ok)
        #expect(!registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("link")]
        )).ok)

        viewModel.insertXomoComponent(.button)
        #expect(!registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("link")]
        )).ok)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("makeMaster")]
        )).ok)
        #expect(!registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("sync")]
        )).ok)
        #expect(!registry.execute(request(
            operation: "call",
            name: "xomo.component.instance",
            arguments: ["action": .string("detach")]
        )).ok)
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

    @Test func registryManagesColorSamplersWithoutMutatingHistory() throws {
        let viewModel = makeViewModel()
        var blueLayer = ImageEditorLayer.blank(
            name: "Blue Overlay",
            size: viewModel.document.canvasSize
        )
        blueLayer.image = NSImage.rendered(size: viewModel.document.canvasSize) { rect in
            NSColor.blue.setFill()
            rect.fill()
        } ?? blueLayer.image
        viewModel.document.layers.append(blueLayer)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let historyCount = viewModel.document.history.count

        let addResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: [
                "x": .number(24),
                "y": .number(18),
                "sampleSize": .string("5x5"),
                "sampleSource": .string("selectedLayer")
            ]
        ))
        #expect(addResponse.ok)
        let added = try #require(addResponse.result?.objectValue)
        #expect(added["index"] == .number(1))
        #expect(added["sampleSize"] == .string("5x5"))
        #expect(added["sampleSource"] == .string("selectedLayer"))
        #expect(viewModel.selectedColorSamplerSampleSize == .fiveByFive)
        #expect(viewModel.selectedColorSamplerSource == .selectedLayer)
        #expect(added["point"]?.objectValue?["x"] == .number(24))
        #expect(added["point"]?.objectValue?["y"] == .number(18))
        #expect(added["color"]?.objectValue?["alpha"] == .number(0))
        #expect(added["rgb8"]?.objectValue?["alpha"] == .number(0))
        #expect(added["hsb"]?.objectValue?["alpha"] == .number(0))
        #expect(added["hexRGBA"] == .string("#00000000"))

        let listResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.list"
        ))
        #expect(listResponse.ok)
        #expect(listResponse.result?.arrayValue?.count == 1)
        #expect(
            listResponse.result?.arrayValue?.first?.objectValue?["point"]?
                .objectValue?["x"] == .number(24)
        )
        #expect(
            listResponse.result?.arrayValue?.first?.objectValue?["sampleSize"]
                == .string("5x5")
        )
        #expect(
            listResponse.result?.arrayValue?.first?.objectValue?["sampleSource"]
                == .string("selectedLayer")
        )
        #expect(viewModel.document.history.count == historyCount)

        let redImage = NSImage.rendered(size: viewModel.document.canvasSize) { rect in
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            rect.fill()
        } ?? NSImage.transparent(size: viewModel.document.canvasSize)
        if let selectedLayerIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[selectedLayerIndex].image = redImage
        }
        let refreshedListResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.list"
        ))
        #expect(refreshedListResponse.ok)
        let refreshedColor = try #require(
            refreshedListResponse.result?.arrayValue?.first?.objectValue?["color"]?.objectValue
        )
        let refreshedRed = try #require(refreshedColor["red"]?.doubleValue)
        let refreshedGreen = try #require(refreshedColor["green"]?.doubleValue)
        let refreshedBlue = try #require(refreshedColor["blue"]?.doubleValue)
        let refreshedAlpha = try #require(refreshedColor["alpha"]?.doubleValue)
        #expect(refreshedRed > 0.8)
        #expect(refreshedRed > refreshedGreen + 0.5)
        #expect(refreshedRed > refreshedBlue + 0.5)
        #expect(refreshedAlpha > 0.95)
        let refreshedSample = try #require(
            refreshedListResponse.result?.arrayValue?.first?.objectValue
        )
        let refreshedRGB8 = try #require(refreshedSample["rgb8"]?.objectValue)
        let refreshedHSB = try #require(refreshedSample["hsb"]?.objectValue)
        let refreshedCMYK = try #require(refreshedSample["cmyk"]?.objectValue)
        let red8 = try #require(refreshedRGB8["red"]?.doubleValue)
        let green8 = try #require(refreshedRGB8["green"]?.doubleValue)
        #expect(red8 > green8 + 100)
        #expect(refreshedRGB8["alpha"] == .number(255))
        #expect((refreshedHSB["saturation"]?.doubleValue ?? 0) > 0.7)
        #expect((refreshedHSB["brightness"]?.doubleValue ?? 0) > 0.8)
        #expect((refreshedCMYK["cyan"]?.doubleValue ?? 1) < 0.05)
        #expect((refreshedCMYK["magenta"]?.doubleValue ?? 0) > 0.95)
        #expect((refreshedCMYK["yellow"]?.doubleValue ?? 0) > 0.95)
        #expect((refreshedCMYK["key"]?.doubleValue ?? 1) < 0.05)
        #expect((refreshedCMYK["alpha"]?.doubleValue ?? 0) > 0.95)
        #expect(refreshedCMYK["conversion"] == .string("deviceRGB"))
        let hexadecimal = try #require(refreshedSample["hexRGBA"]?.stringValue)
        #expect(hexadecimal.hasPrefix("#"))
        #expect(hexadecimal.hasSuffix("FF"))
        #expect(hexadecimal.count == 9)
        #expect(viewModel.document.history.count == historyCount)

        let compositeAddResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: [
                "x": .number(24),
                "y": .number(18),
                "sampleSource": .string("composite")
            ]
        ))
        #expect(compositeAddResponse.ok)
        let compositeSample = try #require(compositeAddResponse.result?.objectValue)
        #expect(compositeSample["sampleSource"] == .string("composite"))
        let compositeColor = try #require(compositeSample["color"]?.objectValue)
        #expect((compositeColor["blue"]?.doubleValue ?? 0) > 0.8)
        #expect((compositeColor["red"]?.doubleValue ?? 1) < 0.2)
        #expect(viewModel.selectedColorSamplerSource == .composite)
        #expect(viewModel.colorSamplerPoints.count == 2)

        let invalidAddResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: [
                "x": .number(640),
                "y": .number(480),
                "sampleSize": .string("1x1"),
                "sampleSource": .string("selectedLayer")
            ]
        ))
        #expect(!invalidAddResponse.ok)
        #expect(invalidAddResponse.error?.contains("inside the canvas") == true)
        #expect(viewModel.colorSamplerPoints.count == 2)
        #expect(viewModel.selectedColorSamplerSampleSize == .fiveByFive)
        #expect(viewModel.selectedColorSamplerSource == .composite)

        let unsupportedSizeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: [
                "x": .number(20),
                "y": .number(14),
                "sampleSize": .string("7x7")
            ]
        ))
        #expect(!unsupportedSizeResponse.ok)
        #expect(unsupportedSizeResponse.error?.contains("Unsupported") == true)
        #expect(viewModel.colorSamplerPoints.count == 2)
        #expect(viewModel.selectedColorSamplerSampleSize == .fiveByFive)

        let unsupportedSourceResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: [
                "x": .number(20),
                "y": .number(14),
                "sampleSource": .string("selection")
            ]
        ))
        #expect(!unsupportedSourceResponse.ok)
        #expect(unsupportedSourceResponse.error?.contains("Unsupported") == true)
        #expect(viewModel.colorSamplerPoints.count == 2)
        #expect(viewModel.selectedColorSamplerSource == .composite)

        let clearResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.clear"
        ))
        #expect(clearResponse.ok)
        #expect(clearResponse.result?.objectValue?["clearedCount"] == .number(2))
        #expect(viewModel.colorSamplerPoints.isEmpty)

        let emptyClearResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.clear"
        ))
        #expect(!emptyClearResponse.ok)
        #expect(emptyClearResponse.error?.contains("No color samplers") == true)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryMovesAndRemovesOneColorSamplerByStableID() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let historyCount = viewModel.document.history.count

        let firstAdd = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: ["x": .number(10), "y": .number(12)]
        ))
        let secondAdd = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.add",
            arguments: ["x": .number(30), "y": .number(24)]
        ))
        #expect(firstAdd.ok)
        #expect(secondAdd.ok)
        let firstID = try #require(firstAdd.result?.objectValue?["id"]?.stringValue)
        let secondID = try #require(secondAdd.result?.objectValue?["id"]?.stringValue)
        #expect(firstID != secondID)

        let moveResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.move",
            arguments: [
                "id": .string(firstID),
                "x": .number(18),
                "y": .number(20)
            ]
        ))
        #expect(moveResponse.ok)
        #expect(moveResponse.result?.objectValue?["id"] == .string(firstID))
        #expect(moveResponse.result?.objectValue?["index"] == .number(1))
        #expect(moveResponse.result?.objectValue?["point"]?.objectValue?["x"] == .number(18))
        #expect(moveResponse.result?.objectValue?["point"]?.objectValue?["y"] == .number(20))
        #expect(viewModel.colorSamplerPoints.count == 2)
        #expect(viewModel.document.history.count == historyCount)

        let originalMovedPoint = try #require(
            viewModel.colorSamplerPoints.first(where: {
                $0.id.uuidString == firstID
            })
        ).point
        let invalidMove = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.move",
            arguments: [
                "id": .string(firstID),
                "x": .number(10_000),
                "y": .number(10_000)
            ]
        ))
        #expect(!invalidMove.ok)
        #expect(
            viewModel.colorSamplerPoints.first(where: {
                $0.id.uuidString == firstID
            })?.point == originalMovedPoint
        )

        let removeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.remove",
            arguments: ["id": .string(secondID)]
        ))
        #expect(removeResponse.ok)
        #expect(
            removeResponse.result?.objectValue?["removed"]?.objectValue?["id"]
                == .string(secondID)
        )
        #expect(removeResponse.result?.objectValue?["remainingCount"] == .number(1))
        #expect(viewModel.colorSamplerPoints.map(\.id.uuidString) == [firstID])

        let repeatedRemove = registry.execute(request(
            operation: "call",
            name: "xomo.color_sampler.remove",
            arguments: ["id": .string(secondID)]
        ))
        #expect(!repeatedRemove.ok)
        #expect(viewModel.colorSamplerPoints.map(\.id.uuidString) == [firstID])
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryInspectsRequestedHistogramChannelWithoutMutatingHistory() throws {
        let viewModel = makeViewModel()
        var blueLayer = ImageEditorLayer.blank(name: "Blue", size: viewModel.document.canvasSize)
        blueLayer.image = NSImage.rendered(size: viewModel.document.canvasSize) { rect in
            NSColor.blue.setFill()
            rect.fill()
        } ?? blueLayer.image
        viewModel.document.layers.append(blueLayer)
        viewModel.selectLayer(blueLayer.id)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let historyCount = viewModel.document.history.count

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: [
                "histogramSource": .string("selectedLayer"),
                "histogramChannel": .string("blue"),
                "histogramRangeLowerLevel": .number(250),
                "histogramRangeUpperLevel": .number(251)
            ]
        ))

        #expect(response.ok)
        let result = try #require(response.result?.objectValue)
        let histogram = try #require(result["histogram"]?.objectValue)
        let selectedLayerHistogram = viewModel.histogramSummary(for: .selectedLayer)
        #expect(histogram["source"] == .string("selectedLayer"))
        #expect(histogram["channel"] == .string("blue"))
        #expect(histogram["sampledPixelCount"] == .number(Double(selectedLayerHistogram.sampledPixelCount)))
        #expect(histogram["pixelCount"] == .number(Double(selectedLayerHistogram.pixelCount)))
        #expect(histogram["transparentPixelCount"] == .number(Double(selectedLayerHistogram.transparentPixelCount)))
        #expect(histogram["average"] == .number(selectedLayerHistogram.averageBlue))
        #expect(histogram["median"] == .number(selectedLayerHistogram.medianBlue))
        #expect(
            histogram["standardDeviation"]
                == .number(selectedLayerHistogram.standardDeviationBlue)
        )
        #expect(histogram["medianRed"] == .number(selectedLayerHistogram.medianRed))
        #expect(histogram["medianGreen"] == .number(selectedLayerHistogram.medianGreen))
        #expect(histogram["medianBlue"] == .number(selectedLayerHistogram.medianBlue))
        #expect(histogram["medianLuminance"] == .number(selectedLayerHistogram.medianLuminance))
        #expect(
            histogram["standardDeviationLuminance"]
                == .number(selectedLayerHistogram.standardDeviationLuminance)
        )
        #expect(histogram["bins"]?.arrayValue?.count == 32)
        let binCounts = try #require(histogram["binCounts"]?.arrayValue)
        #expect(binCounts.count == 32)
        #expect(
            binCounts.reduce(0) { $0 + Int($1.doubleValue ?? 0) }
                == selectedLayerHistogram.pixelCount
        )
        let binPercentiles = try #require(histogram["binPercentiles"]?.arrayValue)
        #expect(binPercentiles.count == 32)
        #expect(binPercentiles.last == .number(1))
        let binLevelRanges = try #require(histogram["binLevelRanges"]?.arrayValue)
        #expect(binLevelRanges.count == 32)
        #expect(binLevelRanges.first?.objectValue?["lowerLevel"] == .number(0))
        #expect(binLevelRanges.first?.objectValue?["upperLevel"] == .number(7))
        #expect(binLevelRanges.last?.objectValue?["lowerLevel"] == .number(248))
        #expect(binLevelRanges.last?.objectValue?["upperLevel"] == .number(255))
        let range = try #require(histogram["range"]?.objectValue)
        #expect(range["lowerLevel"] == .number(248))
        #expect(range["upperLevel"] == .number(255))
        #expect(range["count"] == .number(Double(selectedLayerHistogram.pixelCount)))
        #expect(range["percentage"] == .number(1))
        #expect(histogram["clippedShadowRatio"]?.doubleValue != nil)
        #expect(histogram["clippedHighlightRatio"]?.doubleValue != nil)
        #expect(viewModel.document.history.count == historyCount)

        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 160, height: 240))
        let selectionResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: ["histogramSource": .string("selection")]
        ))
        #expect(selectionResponse.ok)
        #expect(
            selectionResponse.result?.objectValue?["histogram"]?.objectValue?["source"]
                == .string("selection")
        )
        #expect(viewModel.document.history.count == historyCount)

        let invalidResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: ["histogramChannel": .string("cyan")]
        ))
        #expect(!invalidResponse.ok)
        #expect(invalidResponse.error?.contains("Unknown histogram channel") == true)
        #expect(viewModel.document.history.count == historyCount)

        let incompleteRangeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: ["histogramRangeLowerLevel": .number(64)]
        ))
        #expect(!incompleteRangeResponse.ok)
        #expect(incompleteRangeResponse.error?.contains("must be provided together") == true)
        let reversedRangeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: [
                "histogramRangeLowerLevel": .number(192),
                "histogramRangeUpperLevel": .number(64)
            ]
        ))
        #expect(!reversedRangeResponse.ok)
        #expect(reversedRangeResponse.error?.contains("must not exceed") == true)
        let fractionalRangeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: [
                "histogramRangeLowerLevel": .number(64.5),
                "histogramRangeUpperLevel": .number(128)
            ]
        ))
        #expect(!fractionalRangeResponse.ok)
        #expect(fractionalRangeResponse.error?.contains("must be an integer") == true)
        #expect(viewModel.document.history.count == historyCount)

        viewModel.document.selection = nil
        let unavailableSourceResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: ["histogramSource": .string("selection")]
        ))
        #expect(!unavailableSourceResponse.ok)
        #expect(unavailableSourceResponse.error?.contains("Histogram source is unavailable") == true)
        #expect(viewModel.document.history.count == historyCount)

        let wrongTypeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.document.get",
            arguments: ["histogramSource": .bool(true)]
        ))
        #expect(!wrongTypeResponse.ok)
        #expect(wrongTypeResponse.error?.contains("histogramSource must be a string") == true)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryCreatesConfiguredPatternFillLayersWithNormalizedValues() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let createTool = try #require(automationTool(named: "xomo.layer.create", in: toolsResponse))
        let properties = try #require(
            createTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["patternKind"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorPatternOverlayKind.allCases.map { .string($0.rawValue) }
        )
        #expect(properties["patternRed"]?.objectValue?["type"] == .string("number"))
        #expect(properties["patternGreen"]?.objectValue?["type"] == .string("number"))
        #expect(properties["patternBlue"]?.objectValue?["type"] == .string("number"))
        #expect(properties["patternOpacity"]?.objectValue?["type"] == .string("number"))
        #expect(properties["patternScale"]?.objectValue?["type"] == .string("number"))
        #expect(properties["offsetX"]?.objectValue?["type"] == .string("number"))
        #expect(properties["offsetY"]?.objectValue?["type"] == .string("number"))

        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: [
                "kind": .string("patternFill"),
                "patternKind": .string(ImageEditorPatternOverlayKind.dots.rawValue),
                "patternRed": .number(2),
                "patternGreen": .number(-1),
                "patternBlue": .number(0.4),
                "patternOpacity": .number(0),
                "patternScale": .number(999),
                "offsetX": .number(999),
                "offsetY": .number(-999)
            ]
        ))

        #expect(createResponse.ok)
        let content = try #require(viewModel.document.selectedLayer?.patternFillContent?.normalized())
        #expect(content.kind == .dots)
        #expect(content.red == 1)
        #expect(content.green == 0)
        #expect(content.blue == 0.4)
        #expect(content.opacity == 0.05)
        #expect(content.scale == 64)
        #expect(content.offsetX == 128)
        #expect(content.offsetY == -128)

        let layerCount = viewModel.document.layers.count
        let invalidResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: [
                "kind": .string("patternFill"),
                "patternKind": .string("unknown-pattern")
            ]
        ))
        #expect(!invalidResponse.ok)
        #expect(viewModel.document.layers.count == layerCount)
    }

    @Test func registryReadsAndUpdatesSelectedSolidColorFillLayersWithActualCounts() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let settingsTool = try #require(
            automationTool(named: "xomo.layer.solid_color_fill_settings", in: toolsResponse)
        )
        let properties = try #require(
            settingsTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["action"]?.objectValue?["enum"]?.arrayValue
                == [.string("get"), .string("set")]
        )
        #expect(properties["red"]?.objectValue?["type"] == .string("number"))
        #expect(properties["green"]?.objectValue?["type"] == .string("number"))
        #expect(properties["blue"]?.objectValue?["type"] == .string("number"))

        viewModel.solidColorFillRed = 0.10
        viewModel.solidColorFillGreen = 0.20
        viewModel.solidColorFillBlue = 0.30
        viewModel.addSolidColorFillLayer()
        let editableID = try #require(viewModel.document.selectedLayerID)

        viewModel.solidColorFillRed = 0.70
        viewModel.solidColorFillGreen = 0.80
        viewModel.solidColorFillBlue = 0.90
        viewModel.addSolidColorFillLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)
        viewModel.selectLayer(editableID, extendingSelection: true)

        let getResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.solid_color_fill_settings",
            arguments: ["action": .string("get")]
        ))
        #expect(getResponse.ok)
        #expect(getResponse.result?.arrayValue?.count == 2)

        let historyCount = viewModel.document.history.count
        let setArguments: [String: XomoJSONValue] = [
            "action": .string("set"),
            "red": .number(2),
            "green": .number(-1),
            "blue": .number(0.60)
        ]
        let setResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.solid_color_fill_settings",
            arguments: setArguments
        ))
        #expect(setResponse.ok)
        #expect(setResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        let editable = try #require(
            viewModel.document.layers.first(where: { $0.id == editableID })?.solidColorFillContent?.normalized()
        )
        let locked = try #require(
            viewModel.document.layers.first(where: { $0.id == lockedID })?.solidColorFillContent?.normalized()
        )
        #expect(editable.red == 1)
        #expect(editable.green == 0)
        #expect(editable.blue == 0.60)
        #expect(locked.red == 0.70)
        #expect(locked.green == 0.80)
        #expect(locked.blue == 0.90)
        #expect(viewModel.document.history.count == historyCount + 1)

        let duplicateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.solid_color_fill_settings",
            arguments: setArguments
        ))
        #expect(!duplicateResponse.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        let missingChannelResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.solid_color_fill_settings",
            arguments: [
                "action": .string("set"),
                "red": .number(0),
                "green": .number(0)
            ]
        ))
        #expect(!missingChannelResponse.ok)
    }

    @Test func registryCreatesParameterizedSolidColorFillWithoutUIStateLeakage() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let createTool = try #require(
            automationTool(named: "xomo.layer.create", in: toolsResponse)
        )
        let properties = try #require(
            createTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(properties["solidRed"]?.objectValue?["type"] == .string("number"))
        #expect(properties["solidGreen"]?.objectValue?["type"] == .string("number"))
        #expect(properties["solidBlue"]?.objectValue?["type"] == .string("number"))

        viewModel.solidColorFillRed = 0.15
        viewModel.solidColorFillGreen = 0.25
        viewModel.solidColorFillBlue = 0.35
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count

        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: [
                "kind": .string("solidColorFill"),
                "solidRed": .number(2),
                "solidGreen": .number(-1),
                "solidBlue": .number(0.65)
            ]
        ))
        #expect(createResponse.ok)
        #expect(viewModel.document.layers.count == layerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        let content = try #require(
            viewModel.document.selectedLayer?.solidColorFillContent?.normalized()
        )
        #expect(content.red == 1)
        #expect(content.green == 0)
        #expect(content.blue == 0.65)
        #expect(viewModel.solidColorFillRed == 1)
        #expect(viewModel.solidColorFillGreen == 0)
        #expect(viewModel.solidColorFillBlue == 0.65)

        let incompleteResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: [
                "kind": .string("solidColorFill"),
                "solidRed": .number(0.10),
                "solidGreen": .number(0.20)
            ]
        ))
        #expect(!incompleteResponse.ok)
        #expect(viewModel.document.layers.count == layerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func registryReadsAndReplacesCompleteSelectedAdjustmentLayerSettings() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let settingsTool = try #require(
            automationTool(named: "xomo.layer.adjustment_settings", in: toolsResponse)
        )
        let properties = try #require(
            settingsTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["action"]?.objectValue?["enum"]?.arrayValue
                == [.string("get"), .string("set")]
        )
        #expect(properties["amount"]?.objectValue?["type"] == .string("number"))
        #expect(properties["settings"]?.objectValue?["type"] == .string("object"))

        viewModel.selectedAdjustment = .levels
        viewModel.adjustmentValue = 0.20
        viewModel.levelsBlackPoint = 0.15
        viewModel.levelsGamma = 1.75
        viewModel.levelsWhitePoint = 0.90
        viewModel.addAdjustmentLayer()
        let levelsID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedAdjustment = .brightness
        viewModel.adjustmentValue = 0.35
        viewModel.brightnessContrastBrightness = 0.40
        viewModel.brightnessContrastContrast = -0.25
        viewModel.addAdjustmentLayer()
        let brightnessID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(brightnessID)
        viewModel.selectLayer(levelsID, extendingSelection: true)

        let historyCount = viewModel.document.history.count
        let getResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.adjustment_settings",
            arguments: ["action": .string("get")]
        ))
        #expect(getResponse.ok)
        let layers = try #require(getResponse.result?.arrayValue)
        #expect(layers.count == 2)

        let levelResult = layers.compactMap(\.objectValue).first {
            $0["id"] == .string(levelsID.uuidString)
        }
        let levelSettings = levelResult?["settings"]?.objectValue
        #expect(levelResult?["adjustment"] == .string(ImageEditorAdjustment.levels.rawValue))
        #expect(levelResult?["amount"] == .number(0.20))
        #expect(levelResult?["locked"] == .bool(false))
        #expect(levelSettings?["levelsBlackPoint"] == .number(0.15))
        #expect(levelSettings?["levelsGamma"] == .number(1.75))
        #expect(levelSettings?["levelsWhitePoint"] == .number(0.90))

        let brightnessResult = layers.compactMap(\.objectValue).first {
            $0["id"] == .string(brightnessID.uuidString)
        }
        let brightnessSettings = brightnessResult?["settings"]?.objectValue
        #expect(brightnessResult?["adjustment"] == .string(ImageEditorAdjustment.brightness.rawValue))
        #expect(brightnessResult?["locked"] == .bool(true))
        #expect(brightnessSettings?["brightnessContrastBrightness"] == .number(0.40))
        #expect(brightnessSettings?["brightnessContrastContrast"] == .number(-0.25))
        #expect(viewModel.document.history.count == historyCount)

        var replacementSettings = try #require(levelSettings)
        replacementSettings["levelsBlackPoint"] = .number(0.25)
        replacementSettings["levelsGamma"] = .number(2.25)
        let setResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.adjustment_settings",
            arguments: [
                "action": .string("set"),
                "amount": .number(0.70),
                "settings": .object(replacementSettings)
            ]
        ))
        #expect(setResponse.ok)
        #expect(
            setResponse.result?.objectValue?["updatedLayerCount"]
                == .number(1)
        )
        let updatedLevels = try #require(
            viewModel.document.layers.first { $0.id == levelsID }
        )
        #expect(updatedLevels.adjustment?.amount == 0.70)
        #expect(updatedLevels.adjustmentSettings.levelsBlackPoint == 0.25)
        #expect(updatedLevels.adjustmentSettings.levelsGamma == 2.25)
        let lockedBrightness = try #require(
            viewModel.document.layers.first { $0.id == brightnessID }
        )
        #expect(lockedBrightness.adjustment?.amount == 0.35)
        #expect(lockedBrightness.adjustmentSettings.brightnessContrastBrightness == 0.40)
        #expect(viewModel.document.history.count == historyCount + 1)

        let noOpHistoryCount = viewModel.document.history.count
        let noOpResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.adjustment_settings",
            arguments: [
                "action": .string("set"),
                "amount": .number(0.70),
                "settings": .object(replacementSettings)
            ]
        ))
        #expect(!noOpResponse.ok)
        #expect(viewModel.document.history.count == noOpHistoryCount)

        replacementSettings.removeValue(forKey: "levelsGamma")
        let incompleteResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.adjustment_settings",
            arguments: [
                "action": .string("set"),
                "settings": .object(replacementSettings)
            ]
        ))
        #expect(!incompleteResponse.ok)
        #expect(viewModel.document.history.count == noOpHistoryCount)
    }

    @Test func registryReadsAndReplacesCompleteSelectedFilterLayerSettings() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let settingsTool = try #require(
            automationTool(named: "xomo.layer.filter_settings", in: toolsResponse)
        )
        let properties = try #require(
            settingsTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["action"]?.objectValue?["enum"]?.arrayValue
                == [.string("get"), .string("set")]
        )
        #expect(properties["intensity"]?.objectValue?["type"] == .string("number"))
        #expect(properties["settings"]?.objectValue?["type"] == .string("object"))

        viewModel.selectedFilter = .lensCorrection
        viewModel.filterIntensity = 0.80
        viewModel.filterLensDistortion = 0.40
        viewModel.addFilterLayer()
        let lensID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .wave
        viewModel.filterIntensity = 0.55
        viewModel.filterWaveAmplitude = -0.25
        viewModel.filterWaveFrequency = 0.75
        viewModel.addFilterLayer()
        let waveID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(waveID)
        viewModel.selectLayer(lensID, extendingSelection: true)

        let historyCount = viewModel.document.history.count
        let getResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.filter_settings",
            arguments: ["action": .string("get")]
        ))
        #expect(getResponse.ok)
        let layers = try #require(getResponse.result?.arrayValue)
        #expect(layers.count == 2)

        let lensResult = layers.compactMap(\.objectValue).first {
            $0["id"] == .string(lensID.uuidString)
        }
        let lensSettings = lensResult?["settings"]?.objectValue
        #expect(lensResult?["filter"] == .string(ImageEditorFilter.lensCorrection.rawValue))
        #expect(lensResult?["intensity"] == .number(0.80))
        #expect(lensResult?["locked"] == .bool(false))
        #expect(lensSettings?["lensDistortion"] == .number(0.40))

        let waveResult = layers.compactMap(\.objectValue).first {
            $0["id"] == .string(waveID.uuidString)
        }
        let waveSettings = waveResult?["settings"]?.objectValue
        #expect(waveResult?["filter"] == .string(ImageEditorFilter.wave.rawValue))
        #expect(waveResult?["locked"] == .bool(true))
        #expect(waveSettings?["waveAmplitude"] == .number(-0.25))
        #expect(waveSettings?["waveFrequency"] == .number(0.75))
        #expect(viewModel.document.history.count == historyCount)

        var replacementSettings = try #require(lensSettings)
        replacementSettings["lensDistortion"] = .number(-2)
        let setResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.filter_settings",
            arguments: [
                "action": .string("set"),
                "intensity": .number(2),
                "settings": .object(replacementSettings)
            ]
        ))
        #expect(setResponse.ok)
        #expect(
            setResponse.result?.objectValue?["updatedLayerCount"]
                == .number(1)
        )
        let updatedLens = try #require(
            viewModel.document.layers.first { $0.id == lensID }
        )
        #expect(updatedLens.filter?.kind == .lensCorrection)
        #expect(updatedLens.filter?.intensity == 1)
        #expect(updatedLens.filterSettings.lensDistortion == -1)
        #expect(viewModel.selectedFilter == .lensCorrection)
        #expect(viewModel.filterIntensity == 1)
        #expect(viewModel.filterLensDistortion == -1)

        let lockedWave = try #require(
            viewModel.document.layers.first { $0.id == waveID }
        )
        #expect(lockedWave.filter?.intensity == 0.55)
        #expect(lockedWave.filterSettings.waveAmplitude == -0.25)
        #expect(viewModel.document.history.count == historyCount + 1)

        let noOpHistoryCount = viewModel.document.history.count
        let noOpResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.filter_settings",
            arguments: [
                "action": .string("set"),
                "intensity": .number(1),
                "settings": .object(replacementSettings)
            ]
        ))
        #expect(!noOpResponse.ok)
        #expect(viewModel.document.history.count == noOpHistoryCount)

        replacementSettings.removeValue(forKey: "lensDistortion")
        let incompleteResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.filter_settings",
            arguments: [
                "action": .string("set"),
                "settings": .object(replacementSettings)
            ]
        ))
        #expect(!incompleteResponse.ok)
        #expect(viewModel.document.history.count == noOpHistoryCount)
    }

    @Test func registryReadsAndUpdatesMultiStopGradientFillLayersWithoutFlatteningStops() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        func color(_ red: Double, _ green: Double, _ blue: Double) -> XomoJSONValue {
            .object([
                "red": .number(red),
                "green": .number(green),
                "blue": .number(blue)
            ])
        }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let settingsTool = try #require(
            automationTool(named: "xomo.layer.gradient_fill_settings", in: toolsResponse)
        )
        let properties = try #require(
            settingsTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["preset"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorGradientFillPreset.allCases.map { .string($0.rawValue) }
        )
        #expect(
            properties["style"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorGradientFillStyle.allCases.map { .string($0.rawValue) }
        )
        #expect(properties["stops"]?.objectValue?["minItems"] == .number(2))
        #expect(properties["stops"]?.objectValue?["maxItems"] == .number(16))

        viewModel.selectedGradientFillPreset = .blackWhite
        viewModel.selectedGradientFillStyle = .linear
        viewModel.addGradientFillLayer()
        let editableID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedGradientFillPreset = .sunset
        viewModel.selectedGradientFillStyle = .radial
        viewModel.addGradientFillLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)
        viewModel.selectLayer(editableID, extendingSelection: true)

        let initialGetResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.gradient_fill_settings",
            arguments: ["action": .string("get")]
        ))
        #expect(initialGetResponse.ok)
        #expect(initialGetResponse.result?.arrayValue?.count == 2)

        let historyCount = viewModel.document.history.count
        let setArguments: [String: XomoJSONValue] = [
            "action": .string("set"),
            "preset": .string(ImageEditorGradientFillPreset.custom.rawValue),
            "style": .string(ImageEditorGradientFillStyle.diamond.rawValue),
            "reverse": .bool(true),
            "angle": .number(35),
            "scale": .number(1.75),
            "startColor": color(0.10, 0.20, 0.30),
            "endColor": color(0.80, 0.90, 1),
            "stops": .array([
                .object(["position": .number(0), "color": color(0.10, 0.20, 0.30)]),
                .object(["position": .number(0.45), "color": color(0.40, 0.50, 0.60)]),
                .object(["position": .number(1), "color": color(0.80, 0.90, 1)])
            ])
        ]
        let setResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.gradient_fill_settings",
            arguments: setArguments
        ))
        #expect(setResponse.ok)
        #expect(setResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        let editable = try #require(
            viewModel.document.layers.first(where: { $0.id == editableID })?.gradientFillContent?.normalized()
        )
        let locked = try #require(
            viewModel.document.layers.first(where: { $0.id == lockedID })?.gradientFillContent?.normalized()
        )
        #expect(editable.preset == .custom)
        #expect(editable.style == .diamond)
        #expect(editable.reverse)
        #expect(editable.angle == 35)
        #expect(editable.scale == 1.75)
        #expect(editable.colorStops?.count == 3)
        #expect(editable.colorStops?[1].position == 0.45)
        #expect(editable.colorStops?[1].green == 0.50)
        #expect(locked.preset == .sunset)
        #expect(locked.style == .radial)
        #expect(locked.colorStops == nil)
        #expect(viewModel.document.history.count == historyCount + 1)

        let duplicateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.gradient_fill_settings",
            arguments: setArguments
        ))
        #expect(!duplicateResponse.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        let getResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.gradient_fill_settings",
            arguments: ["action": .string("get")]
        ))
        let editableResult = getResponse.result?.arrayValue?.compactMap(\.objectValue).first {
            $0["id"] == .string(editableID.uuidString)
        }
        #expect(getResponse.ok)
        #expect(editableResult?["stops"]?.arrayValue?.count == 3)

        var invalidArguments = setArguments
        invalidArguments["stops"] = .array([
            .object(["position": .number(0), "color": color(0, 0, 0)]),
            .object(["position": .number(0.75), "color": color(0.50, 0.50, 0.50)]),
            .object(["position": .number(0.50), "color": color(1, 1, 1)])
        ])
        let invalidResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.gradient_fill_settings",
            arguments: invalidArguments
        ))
        #expect(!invalidResponse.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.selectLayer(editableID)
        viewModel.gradientFillStartRed = 0.95
        viewModel.updateSelectedGradientFillLayer()
        let retained = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        #expect(retained.colorStops?.count == 3)
        #expect(retained.colorStops?[0].red == 0.95)
        #expect(retained.colorStops?[1].position == 0.45)
        #expect(retained.colorStops?[1].green == 0.50)
    }

    @Test func registryCreatesParameterizedMultiStopGradientFillWithoutUIStateLeakage() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        func color(_ red: Double, _ green: Double, _ blue: Double) -> XomoJSONValue {
            .object([
                "red": .number(red),
                "green": .number(green),
                "blue": .number(blue)
            ])
        }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let createTool = try #require(
            automationTool(named: "xomo.layer.create", in: toolsResponse)
        )
        let properties = try #require(
            createTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["preset"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorGradientFillPreset.allCases.map { .string($0.rawValue) }
        )
        #expect(properties["stops"]?.objectValue?["minItems"] == .number(2))
        #expect(properties["stops"]?.objectValue?["maxItems"] == .number(16))

        viewModel.selectedGradientFillPreset = .sunset
        viewModel.selectedGradientFillStyle = .radial
        viewModel.gradientFillReverse = false
        viewModel.gradientFillAngle = -120
        viewModel.gradientFillScale = 0.50

        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let createArguments: [String: XomoJSONValue] = [
            "kind": .string("gradientFill"),
            "preset": .string(ImageEditorGradientFillPreset.custom.rawValue),
            "style": .string(ImageEditorGradientFillStyle.reflected.rawValue),
            "reverse": .bool(true),
            "angle": .number(80),
            "scale": .number(2.25),
            "startColor": color(0.05, 0.10, 0.15),
            "endColor": color(0.85, 0.90, 0.95),
            "stops": .array([
                .object(["position": .number(0), "color": color(0.05, 0.10, 0.15)]),
                .object(["position": .number(0.25), "color": color(0.30, 0.35, 0.40)]),
                .object(["position": .number(0.70), "color": color(0.60, 0.65, 0.70)]),
                .object(["position": .number(1), "color": color(0.85, 0.90, 0.95)])
            ])
        ]
        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: createArguments
        ))
        #expect(createResponse.ok)
        #expect(viewModel.document.layers.count == layerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        let content = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        #expect(content.preset == .custom)
        #expect(content.style == .reflected)
        #expect(content.reverse)
        #expect(content.angle == 80)
        #expect(content.scale == 2.25)
        #expect(content.colorStops?.count == 4)
        #expect(content.colorStops?[1].position == 0.25)
        #expect(content.colorStops?[2].blue == 0.70)

        var invalidArguments = createArguments
        invalidArguments["stops"] = .array([
            .object(["position": .number(0.10), "color": color(0, 0, 0)]),
            .object(["position": .number(1), "color": color(1, 1, 1)])
        ])
        let invalidResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: invalidArguments
        ))
        #expect(!invalidResponse.ok)
        #expect(viewModel.document.layers.count == layerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func registryReadsAndUpdatesSelectedPatternFillLayersWithActualCounts() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let settingsTool = try #require(
            automationTool(named: "xomo.layer.pattern_fill_settings", in: toolsResponse)
        )
        let properties = try #require(
            settingsTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            properties["patternKind"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorPatternOverlayKind.allCases.map { .string($0.rawValue) }
        )
        #expect(properties["offsetX"]?.objectValue?["type"] == .string("number"))
        #expect(properties["offsetY"]?.objectValue?["type"] == .string("number"))

        viewModel.selectedPatternFillKind = .checkerboard
        viewModel.patternFillRed = 0.10
        viewModel.patternFillGreen = 0.20
        viewModel.patternFillBlue = 0.30
        viewModel.patternFillOpacity = 0.40
        viewModel.patternFillScale = 12
        viewModel.addPatternFillLayer()
        let editableID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedPatternFillKind = .dots
        viewModel.patternFillOpacity = 0.70
        viewModel.patternFillScale = 20
        viewModel.addPatternFillLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)
        viewModel.selectLayer(editableID, extendingSelection: true)

        let getResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.pattern_fill_settings",
            arguments: ["action": .string("get")]
        ))
        #expect(getResponse.ok)
        #expect(getResponse.result?.arrayValue?.count == 2)

        let historyCount = viewModel.document.history.count
        let setArguments: [String: XomoJSONValue] = [
            "action": .string("set"),
            "patternKind": .string(ImageEditorPatternOverlayKind.diagonalStripes.rawValue),
            "red": .number(2),
            "green": .number(-1),
            "blue": .number(0.75),
            "opacity": .number(0),
            "scale": .number(999),
            "offsetX": .number(-999),
            "offsetY": .number(999)
        ]
        let setResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.pattern_fill_settings",
            arguments: setArguments
        ))
        #expect(setResponse.ok)
        #expect(setResponse.result?.objectValue?["updatedLayerCount"] == .number(1))
        let editable = try #require(
            viewModel.document.layers.first(where: { $0.id == editableID })?.patternFillContent?.normalized()
        )
        let locked = try #require(
            viewModel.document.layers.first(where: { $0.id == lockedID })?.patternFillContent?.normalized()
        )
        #expect(editable.kind == .diagonalStripes)
        #expect(editable.red == 1)
        #expect(editable.green == 0)
        #expect(editable.blue == 0.75)
        #expect(editable.opacity == 0.05)
        #expect(editable.scale == 64)
        #expect(editable.offsetX == -128)
        #expect(editable.offsetY == 128)
        #expect(locked.kind == .dots)
        #expect(locked.opacity == 0.70)
        #expect(viewModel.document.history.count == historyCount + 1)

        let duplicateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.pattern_fill_settings",
            arguments: setArguments
        ))
        #expect(!duplicateResponse.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        let invalidResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.pattern_fill_settings",
            arguments: [
                "action": .string("set"),
                "patternKind": .string("unknown-pattern"),
                "red": .number(0),
                "green": .number(0),
                "blue": .number(0),
                "opacity": .number(1),
                "scale": .number(16),
                "offsetX": .number(0),
                "offsetY": .number(0)
            ]
        ))
        #expect(!invalidResponse.ok)
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

        let originalAnchor = try #require(viewModel.selectedPathAnchorCanvasPoint)
        let selectResponse = registry.execute(request(
            operation: "call",
            name: "xomo.path.action",
            arguments: [
                "action": .string("select"),
                "subpath": .number(0),
                "anchor": .number(0)
            ]
        ))
        #expect(selectResponse.ok)
        let nudgeResponse = registry.execute(request(
            operation: "call",
            name: "xomo.path.action",
            arguments: [
                "action": .string("nudgeAnchor"),
                "dx": .number(5),
                "dy": .number(-2)
            ]
        ))
        #expect(nudgeResponse.ok)
        let movedAnchor = try #require(viewModel.selectedPathAnchorCanvasPoint)
        #expect(movedAnchor == CGPoint(x: originalAnchor.x + 5, y: originalAnchor.y - 2))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))

        let inspectResponse = registry.execute(request(operation: "call", name: "xomo.path.get"))
        #expect(inspectResponse.ok)
        guard case .object(let path) = inspectResponse.result else {
            Issue.record("Expected path object")
            return
        }
        #expect(path["active"] == .bool(true))
        #expect(path["closed"] == .bool(true))
    }

    @Test func registryCreatesInspectsAndUpdatesRectangleCornerRadius() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let historyCountBeforeCreate = viewModel.document.history.count
        let selectedLayerIDBeforeCreate = viewModel.document.selectedLayerID
        let createResponse = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(20),
                "y": .number(30),
                "width": .number(80),
                "height": .number(40),
                "fillColor": .object([
                    "red": .number(1), "green": .number(0), "blue": .number(0)
                ]),
                "fillOpacity": .number(0.6),
                "strokeColor": .object([
                    "red": .number(0), "green": .number(0), "blue": .number(1)
                ]),
                "strokeOpacity": .number(0.8),
                "strokeWidth": .number(7),
                "strokePosition": .string("outside"),
                "strokeCap": .string("square"),
                "strokeJoin": .string("miter"),
                "strokeMiterLimit": .number(4),
                "strokeDashPattern": .array([.number(8), .number(4)]),
                "cornerRadius": .number(40),
                "cornerSmoothing": .number(0.5)
            ]
        ))
        #expect(createResponse.ok)
        let createdResult = try #require(createResponse.result?.objectValue)
        let createdLayerID = try #require(viewModel.document.selectedLayerID)
        #expect(createdLayerID != selectedLayerIDBeforeCreate)
        #expect(createdResult["created"] == .bool(true))
        #expect(createdResult["layerId"] == .string(createdLayerID.uuidString))
        #expect(createdResult["selectedLayerId"] == .string(createdLayerID.uuidString))
        #expect(createdResult["x"] == .number(20))
        #expect(createdResult["y"] == .number(30))
        #expect(createdResult["width"] == .number(80))
        #expect(createdResult["height"] == .number(40))
        #expect(createdResult["strokePosition"] == .string("outside"))
        #expect(createdResult["strokeDashPattern"] == .array([.number(8), .number(4)]))
        #expect(createdResult["historyCount"] == .number(Double(historyCountBeforeCreate + 1)))
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadius == 20)
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerSmoothing == 0.5)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillOpacity == 0.6)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeOpacity == 0.8)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == 7)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokePosition == .outside)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeCap == .square)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeJoin == .miter)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeMiterLimit == 4)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern == [8, 4])
        #expect(viewModel.document.history.count == historyCountBeforeCreate + 1)

        let inspectResponse = registry.execute(request(
            operation: "call",
            name: "xomo.shape.get"
        ))
        guard case .object(let inspectedShape) = inspectResponse.result else {
            Issue.record("Expected shape result")
            return
        }
        #expect(inspectedShape["kind"] == .string("rectangle"))
        #expect(inspectedShape["cornerRadius"] == .number(20))
        #expect(inspectedShape["cornerSmoothing"] == .number(0.5))
        #expect(inspectedShape["fillOpacity"] == .number(0.6))
        #expect(inspectedShape["strokeOpacity"] == .number(0.8))
        #expect(inspectedShape["strokeWidth"] == .number(7))
        #expect(inspectedShape["strokePosition"] == .string("outside"))
        #expect(inspectedShape["strokeCap"] == .string("square"))
        #expect(inspectedShape["strokeJoin"] == .string("miter"))
        #expect(inspectedShape["strokeMiterLimit"] == .number(4))
        #expect(inspectedShape["strokeDashPattern"] == .array([.number(8), .number(4)]))

        let historyCountBeforeUpdate = viewModel.document.history.count
        let updateResponse = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "cornerRadius": .number(6),
                "strokeColor": .object([
                    "red": .number(0), "green": .number(1), "blue": .number(0)
                ]),
                "strokeOpacity": .number(0.35)
            ]
        ))
        #expect(updateResponse.ok)
        #expect(updateResponse.result == .object(["updatedLayerCount": .number(1)]))
        let updated = try #require(viewModel.document.selectedLayer?.shapeContent)
        let updatedStroke = try #require(updated.strokeColor.usingColorSpace(.deviceRGB))
        let unchangedFill = try #require(updated.fillColor.usingColorSpace(.deviceRGB))
        #expect(updated.cornerRadius == 6)
        #expect(updated.strokeOpacity == 0.35)
        #expect(updatedStroke.greenComponent > 0.99)
        #expect(unchangedFill.redComponent > 0.99)
        #expect(updated.fillOpacity == 0.6)
        #expect(viewModel.document.history.count == historyCountBeforeUpdate + 1)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadius == 20)

        let invalidColorUpdate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillColor": .object([
                    "red": .number(2), "green": .number(0), "blue": .number(0)
                ])
            ]
        ))
        #expect(!invalidColorUpdate.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillOpacity == 0.6)

        let independentUpdate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "cornerRadii": .object([
                    "topLeft": .number(4),
                    "topRight": .number(8),
                    "bottomRight": .number(12),
                    "bottomLeft": .number(16)
                ]),
                "cornerSmoothing": .number(0.8)
            ]
        ))
        #expect(independentUpdate.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadii == ImageEditorRectangleCornerRadii(
            topLeft: 4,
            topRight: 8,
            bottomRight: 12,
            bottomLeft: 16
        ))
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerSmoothing == 0.8)

        let independentInspect = registry.execute(request(
            operation: "call",
            name: "xomo.shape.get"
        ))
        guard case .object(let independentShape) = independentInspect.result else {
            Issue.record("Expected independent-corner shape result")
            return
        }
        #expect(independentShape["usesIndependentCornerRadii"] == .bool(true))
        #expect(independentShape["cornerSmoothing"] == .number(0.8))
        #expect(independentShape["cornerRadii"] == .object([
            "topLeft": .number(4),
            "topRight": .number(8),
            "bottomRight": .number(12),
            "bottomLeft": .number(16)
        ]))

        let conflictingUpdate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "cornerRadius": .number(5),
                "cornerRadii": .object([
                    "topLeft": .number(1),
                    "topRight": .number(2),
                    "bottomRight": .number(3),
                    "bottomLeft": .number(4)
                ])
            ]
        ))
        #expect(!conflictingUpdate.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadii?.bottomLeft == 16)

        let layerCountBeforeInvalidCreate = viewModel.document.layers.count
        let historyCountBeforeInvalidCreate = viewModel.document.history.count
        let invalidCreate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(0), "y": .number(0),
                "width": .number(40), "height": .number(30),
                "strokePosition": .string("overlay"),
                "strokeDashPattern": .array([.number(4)])
            ]
        ))
        #expect(!invalidCreate.ok)
        #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
        #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)

        let undersizedCreate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(0), "y": .number(0),
                "width": .number(3), "height": .number(20)
            ]
        ))
        #expect(!undersizedCreate.ok)
        #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
        #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)

        for invalidKind: XomoJSONValue in [
            .string("triangle"),
            .string("path"),
            .string("Rectangle"),
            .number(1)
        ] {
            let invalidKindCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": invalidKind,
                    "x": .number(0), "y": .number(0),
                    "width": .number(40), "height": .number(20)
                ]
            ))
            #expect(!invalidKindCreate.ok)
            #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
            #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)
        }

        for invalidMiterLimit: XomoJSONValue in [
            .number(0),
            .number(1_001),
            .string("4"),
            .bool(true)
        ] {
            let invalidMiterCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(0), "y": .number(0),
                    "width": .number(40), "height": .number(20),
                    "strokeMiterLimit": invalidMiterLimit
                ]
            ))
            #expect(!invalidMiterCreate.ok)
            #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
            #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)
        }

        for invalidStrokeWidth: XomoJSONValue in [
            .number(0),
            .number(96.1),
            .string("12"),
            .bool(true)
        ] {
            let invalidStrokeCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(0), "y": .number(0),
                    "width": .number(40), "height": .number(20),
                    "strokeWidth": invalidStrokeWidth
                ]
            ))
            #expect(!invalidStrokeCreate.ok)
            #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
            #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)
        }

        for (key, value): (String, XomoJSONValue) in [
            ("fillOpacity", .number(-0.01)),
            ("fillOpacity", .string("0.5")),
            ("strokeOpacity", .number(1.01)),
            ("strokeOpacity", .bool(true))
        ] {
            let invalidOpacityCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(0), "y": .number(0),
                    "width": .number(40), "height": .number(20),
                    key: value
                ]
            ))
            #expect(!invalidOpacityCreate.ok)
            #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
            #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)
        }

        for (key, value): (String, XomoJSONValue) in [
            ("cornerRadius", .number(-1)),
            ("cornerRadius", .string("4")),
            ("cornerSmoothing", .number(-0.01)),
            ("cornerSmoothing", .number(1.01)),
            ("cornerSmoothing", .bool(true))
        ] {
            let invalidCornerCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(0), "y": .number(0),
                    "width": .number(40), "height": .number(20),
                    key: value
                ]
            ))
            #expect(!invalidCornerCreate.ok)
            #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
            #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)
        }

        for invalidCornerRadii: XomoJSONValue in [
            .object([
                "topLeft": .number(-1), "topRight": .number(2),
                "bottomRight": .number(3), "bottomLeft": .number(4)
            ]),
            .object([
                "topLeft": .string("1"), "topRight": .number(2),
                "bottomRight": .number(3), "bottomLeft": .number(4)
            ])
        ] {
            let invalidCornerCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(0), "y": .number(0),
                    "width": .number(40), "height": .number(20),
                    "cornerRadii": invalidCornerRadii
                ]
            ))
            #expect(!invalidCornerCreate.ok)
            #expect(viewModel.document.layers.count == layerCountBeforeInvalidCreate)
            #expect(viewModel.document.history.count == historyCountBeforeInvalidCreate)
        }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let createTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.create")
        })
        let createProperties = try #require(
            createTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(
            createProperties["strokePosition"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorStrokePosition.allCases.map { .string($0.rawValue) }
        )
        #expect(
            createProperties["strokeCap"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorStrokeCap.allCases.map { .string($0.rawValue) }
        )
        #expect(
            createProperties["strokeJoin"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorStrokeJoin.allCases.map { .string($0.rawValue) }
        )
        #expect(createProperties["strokeMiterLimit"]?.objectValue?["type"] == .string("number"))
        #expect(createProperties["strokeWidth"]?.objectValue?["minimum"] == .number(0.1))
        #expect(createProperties["strokeWidth"]?.objectValue?["maximum"] == .number(96))
        #expect(createProperties["fillOpacity"]?.objectValue?["minimum"] == .number(0))
        #expect(createProperties["fillOpacity"]?.objectValue?["maximum"] == .number(1))
        #expect(createProperties["strokeOpacity"]?.objectValue?["minimum"] == .number(0))
        #expect(createProperties["strokeOpacity"]?.objectValue?["maximum"] == .number(1))
        #expect(createProperties["cornerRadius"]?.objectValue?["minimum"] == .number(0))
        #expect(createProperties["cornerSmoothing"]?.objectValue?["minimum"] == .number(0))
        #expect(createProperties["cornerSmoothing"]?.objectValue?["maximum"] == .number(1))
        let cornerProperties = createProperties["cornerRadii"]?.objectValue?["properties"]?.objectValue
        #expect(cornerProperties?["topLeft"]?.objectValue?["minimum"] == .number(0))
        #expect(createProperties["strokeDashPattern"]?.objectValue?["type"] == .string("array"))
    }

    @Test func ellipseCreationRejectsRectangleOnlyCornerArgumentsAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let selectedLayerID = viewModel.document.selectedLayerID

        for (key, value): (String, XomoJSONValue) in [
            ("cornerRadius", .number(0)),
            ("cornerRadii", .object([
                "topLeft": .number(0), "topRight": .number(0),
                "bottomRight": .number(0), "bottomLeft": .number(0)
            ])),
            ("cornerSmoothing", .number(0))
        ] {
            let response = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("ellipse"),
                    "x": .number(10), "y": .number(12),
                    "width": .number(90), "height": .number(70),
                    key: value
                ]
            ))
            #expect(!response.ok)
            #expect(response.error?.contains("only supported when kind is rectangle") == true)
            #expect(viewModel.document.layers.count == layerCount)
            #expect(viewModel.document.history.count == historyCount)
            #expect(viewModel.document.selectedLayerID == selectedLayerID)
        }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let createTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.create")
        })
        let properties = createTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        #expect(
            properties?["cornerRadius"]?.objectValue?["description"]
                == .string("Rectangle-only uniform corner radius in pixels")
        )
        #expect(
            properties?["cornerSmoothing"]?.objectValue?["description"]
                == .string("Rectangle-only editable superellipse smoothing from 0 through 1")
        )
    }

    @Test func shapeStrokeWidthAutomationRejectsInvalidValuesAtomically() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 88, y: 48),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 98, y: 18),
            to: CGPoint(x: 178, y: 58),
            ellipse: true
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "strokeWidth": .number(12),
                "strokeCap": .string("square")
            ]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(2)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        for layerID in [firstID, secondID] {
            let content = viewModel.document.layers.first { $0.id == layerID }?.shapeContent
            #expect(content?.strokeWidth == 12)
            #expect(content?.strokeCap == .square)
        }

        let stableHistoryCount = viewModel.document.history.count
        for invalidStrokeWidth: XomoJSONValue in [
            .number(0),
            .number(96.1),
            .string("12"),
            .bool(true)
        ] {
            let invalid = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "strokeWidth": invalidStrokeWidth,
                    "strokeCap": .string("round")
                ]
            ))
            #expect(!invalid.ok)
            #expect(viewModel.document.history.count == stableHistoryCount)
            for layerID in [firstID, secondID] {
                let content = viewModel.document.layers.first { $0.id == layerID }?.shapeContent
                #expect(content?.strokeWidth == 12)
                #expect(content?.strokeCap == .square)
            }
        }

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["strokeWidth"] == .number(12))

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        let schema = updateTool["inputSchema"]?.objectValue?["properties"]?
            .objectValue?["strokeWidth"]?.objectValue
        #expect(schema?["minimum"] == .number(0.1))
        #expect(schema?["maximum"] == .number(96))
    }

    @Test func shapeOpacityAutomationValidatesIndependentAndLegacyValuesAtomically() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 88, y: 48),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 98, y: 18),
            to: CGPoint(x: 178, y: 58),
            ellipse: true
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "opacity": .number(0.4),
                "fillOpacity": .number(0.7)
            ]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(2)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        for layerID in [firstID, secondID] {
            let content = viewModel.document.layers.first { $0.id == layerID }?.shapeContent
            #expect(content?.fillOpacity == 0.7)
            #expect(content?.strokeOpacity == 0.4)
        }

        let stableHistoryCount = viewModel.document.history.count
        for (key, value): (String, XomoJSONValue) in [
            ("opacity", .number(-0.01)),
            ("opacity", .string("0.5")),
            ("fillOpacity", .number(1.01)),
            ("fillOpacity", .bool(true)),
            ("strokeOpacity", .number(-1)),
            ("strokeOpacity", .string("0.5"))
        ] {
            let invalid = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [key: value, "strokeWidth": .number(12)]
            ))
            #expect(!invalid.ok)
            #expect(viewModel.document.history.count == stableHistoryCount)
            for layerID in [firstID, secondID] {
                let content = viewModel.document.layers.first { $0.id == layerID }?.shapeContent
                #expect(content?.fillOpacity == 0.7)
                #expect(content?.strokeOpacity == 0.4)
                #expect(content?.strokeWidth != 12)
            }
        }

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["fillOpacity"] == .number(0.7))
        #expect(inspected.result?.objectValue?["strokeOpacity"] == .number(0.4))

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        let properties = updateTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        for key in ["opacity", "fillOpacity", "strokeOpacity"] {
            #expect(properties?[key]?.objectValue?["minimum"] == .number(0))
            #expect(properties?[key]?.objectValue?["maximum"] == .number(1))
        }
    }

    @Test func shapeCornerAutomationRejectsInvalidGeometryAtomically() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 88, y: 48),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 98, y: 18),
            to: CGPoint(x: 178, y: 58),
            ellipse: false
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "cornerRadii": .object([
                    "topLeft": .number(4), "topRight": .number(8),
                    "bottomRight": .number(12), "bottomLeft": .number(16)
                ]),
                "cornerSmoothing": .number(0.75)
            ]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(2)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        for layerID in [firstID, secondID] {
            let content = viewModel.document.layers.first { $0.id == layerID }?.shapeContent
            #expect(content?.cornerRadii?.bottomLeft == 16)
            #expect(content?.cornerSmoothing == 0.75)
        }

        let stableHistoryCount = viewModel.document.history.count
        for arguments: [String: XomoJSONValue] in [
            ["cornerRadius": .number(-1), "strokeWidth": .number(12)],
            ["cornerRadius": .string("4"), "strokeWidth": .number(12)],
            ["cornerSmoothing": .number(1.01), "strokeWidth": .number(12)],
            ["cornerSmoothing": .bool(true), "strokeWidth": .number(12)],
            [
                "cornerRadii": .object([
                    "topLeft": .number(4), "topRight": .number(-1),
                    "bottomRight": .number(12), "bottomLeft": .number(16)
                ]),
                "strokeWidth": .number(12)
            ]
        ] {
            let invalid = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: arguments
            ))
            #expect(!invalid.ok)
            #expect(viewModel.document.history.count == stableHistoryCount)
            for layerID in [firstID, secondID] {
                let content = viewModel.document.layers.first { $0.id == layerID }?.shapeContent
                #expect(content?.cornerRadii?.bottomLeft == 16)
                #expect(content?.cornerSmoothing == 0.75)
                #expect(content?.strokeWidth != 12)
            }
        }

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["cornerSmoothing"] == .number(0.75))

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        let properties = updateTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        #expect(properties?["cornerRadius"]?.objectValue?["minimum"] == .number(0))
        #expect(properties?["cornerSmoothing"]?.objectValue?["minimum"] == .number(0))
        #expect(properties?["cornerSmoothing"]?.objectValue?["maximum"] == .number(1))
        let radii = properties?["cornerRadii"]?.objectValue?["properties"]?.objectValue
        for key in ["topLeft", "topRight", "bottomRight", "bottomLeft"] {
            #expect(radii?[key]?.objectValue?["minimum"] == .number(0))
        }
    }

    @Test func shapeStrokePositionAutomationUpdatesOnlyChangedShapesAndRejectsUnknownValues() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 58, y: 18),
            to: CGPoint(x: 108, y: 68),
            ellipse: false
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        var secondContent = try #require(viewModel.document.layers[secondIndex].shapeContent)
        secondContent.strokePosition = .outside
        viewModel.document.layers[secondIndex].kind = .shape(secondContent)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokePosition": .string("outside")]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(1)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokePosition == .outside)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokePosition == .outside)

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["strokePosition"] == .string("outside"))

        let repeatedHistoryCount = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokePosition": .string("outside")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokePosition": .string("overlay")]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        #expect(
            updateTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["strokePosition"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorStrokePosition.allCases.map { .string($0.rawValue) }
        )
    }

    @Test func shapeStrokeDashAutomationUpdatesOnlyChangedShapesAndRejectsInvalidPatterns() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 58, y: 18),
            to: CGPoint(x: 108, y: 68),
            ellipse: false
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        var secondContent = try #require(viewModel.document.layers[secondIndex].shapeContent)
        secondContent.strokeDashPattern = [8, 4]
        viewModel.document.layers[secondIndex].kind = .shape(secondContent)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeDashPattern": .array([.number(8), .number(4)])]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(1)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeDashPattern == [8, 4])
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeDashPattern == [8, 4])

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["strokeDashPattern"] == .array([.number(8), .number(4)]))

        let repeatedHistoryCount = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeDashPattern": .array([.number(8), .number(4)])]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        for invalidPattern: XomoJSONValue in [
            .array([.number(4)]),
            .array([.number(6), .number(-1)]),
            .string("6,3")
        ] {
            let invalid = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: ["strokeDashPattern": invalidPattern]
            ))
            #expect(!invalid.ok)
            #expect(viewModel.document.history.count == repeatedHistoryCount)
            #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeDashPattern == [8, 4])
        }

        let cleared = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeDashPattern": .array([])]
        ))
        #expect(cleared.ok)
        #expect(cleared.result == .object(["updatedLayerCount": .number(2)]))
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeDashPattern.isEmpty == true)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeDashPattern.isEmpty == true)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        let dashSchema = try #require(
            updateTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["strokeDashPattern"]?.objectValue
        )
        #expect(dashSchema["type"] == .string("array"))
        #expect(dashSchema["maxItems"] == .number(16))
        #expect(dashSchema["items"]?.objectValue?["type"] == .string("number"))
    }

    @Test func shapeMiterLimitAutomationUpdatesOnlyChangedShapesAndReportsCount() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 58, y: 18),
            to: CGPoint(x: 108, y: 68),
            ellipse: false
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        var secondContent = try #require(viewModel.document.layers[secondIndex].shapeContent)
        secondContent.strokeJoin = .miter
        secondContent.strokeMiterLimit = 4
        viewModel.document.layers[secondIndex].kind = .shape(secondContent)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "strokeJoin": .string("miter"),
                "strokeMiterLimit": .number(4)
            ]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(1)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeMiterLimit == 4)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeMiterLimit == 4)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeJoin == .miter)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeJoin == .miter)

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["strokeJoin"] == .string("miter"))
        #expect(inspected.result?.objectValue?["strokeMiterLimit"] == .number(4))

        let repeatedHistoryCount = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "strokeJoin": .string("miter"),
                "strokeMiterLimit": .number(4)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeJoin": .string("future")]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        for invalidMiterLimit: XomoJSONValue in [
            .number(0),
            .number(1_001),
            .string("4"),
            .bool(true)
        ] {
            let invalidMiter = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: ["strokeMiterLimit": invalidMiterLimit]
            ))
            #expect(!invalidMiter.ok)
            #expect(viewModel.document.history.count == repeatedHistoryCount)
            #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeMiterLimit == 4)
            #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeMiterLimit == 4)
        }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        #expect(
            updateTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["strokeMiterLimit"]?.objectValue?["type"] == .string("number")
        )
        #expect(
            updateTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["strokeJoin"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorStrokeJoin.allCases.map { .string($0.rawValue) }
        )
    }

    @Test func shapeStrokeCapAutomationUpdatesOnlyChangedShapesAndRejectsUnknownValues() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 58, y: 18),
            to: CGPoint(x: 108, y: 68),
            ellipse: false
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        var secondContent = try #require(viewModel.document.layers[secondIndex].shapeContent)
        secondContent.strokeCap = .square
        viewModel.document.layers[secondIndex].kind = .shape(secondContent)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeCap": .string("square")]
        ))
        #expect(updated.ok)
        #expect(updated.result == .object(["updatedLayerCount": .number(1)]))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeCap == .square)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeCap == .square)

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        #expect(inspected.result?.objectValue?["strokeCap"] == .string("square"))

        let repeatedHistoryCount = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeCap": .string("square")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["strokeCap": .string("arrow")]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == repeatedHistoryCount)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let updateTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.update")
        })
        #expect(
            updateTool["inputSchema"]?.objectValue?["properties"]?
                .objectValue?["strokeCap"]?.objectValue?["enum"]?.arrayValue
                == ImageEditorStrokeCap.allCases.map { .string($0.rawValue) }
        )
    }

    @Test func registryCreatesInspectsUpdatesAndClearsShapeLinearGradient() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10),
                "y": .number(12),
                "width": .number(90),
                "height": .number(50),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object([
                    "stops": .array([
                        .object([
                            "position": .number(0),
                            "color": .object([
                                "red": .number(1), "green": .number(0), "blue": .number(0)
                            ])
                        ]),
                        .object([
                            "position": .number(0.4),
                            "color": .object([
                                "red": .number(0), "green": .number(1), "blue": .number(0)
                            ])
                        ]),
                        .object([
                            "position": .number(1),
                            "color": .object([
                                "red": .number(0), "green": .number(0), "blue": .number(1)
                            ])
                        ])
                    ]),
                    "angle": .number(30),
                    "scale": .number(1.5),
                    "centerX": .number(0.35),
                    "centerY": .number(0.65)
                ]),
                "fillOpacity": .number(0.7)
            ]
        ))
        #expect(created.ok)
        let shape = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(shape.fillGradient?.angle == 30)
        #expect(shape.fillGradient?.scale == 1.5)
        #expect(shape.fillGradient?.shapeColorStops.count == 3)
        #expect(shape.fillGradient?.shapeColorStops[1].position == 0.4)
        #expect(shape.fillGradientCenter == CGPoint(x: 0.35, y: 0.65))
        #expect(shape.fillOpacity == 0.7)

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        guard case .object(let result) = inspected.result else {
            Issue.record("Expected gradient shape result")
            return
        }
        #expect(result["fillKind"] == .string("linearGradient"))
        guard case .object(let gradientResult) = result["fillGradient"] else {
            Issue.record("Expected editable gradient payload")
            return
        }
        #expect(gradientResult["angle"] == .number(30))
        #expect(gradientResult["scale"] == .number(1.5))
        #expect(gradientResult["centerX"] == .number(0.35))
        #expect(gradientResult["centerY"] == .number(0.65))
        guard case .array(let stopResult) = gradientResult["stops"] else {
            Issue.record("Expected editable gradient stops")
            return
        }
        #expect(stopResult.count == 3)

        let previousStroke = shape.strokeColor
        let updated = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["fillKind": .string("solid")]
        ))
        #expect(updated.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == nil)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeColor.isEqual(previousStroke) == true)

        let conflicting = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillKind": .string("solid"),
                "fillGradient": .object([
                    "startColor": .object([
                        "red": .number(1), "green": .number(0), "blue": .number(0)
                    ]),
                    "endColor": .object([
                        "red": .number(0), "green": .number(0), "blue": .number(1)
                    ])
                ])
            ]
        ))
        #expect(!conflicting.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == nil)

        let missingGradient = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("ellipse"),
                "x": .number(120),
                "y": .number(12),
                "width": .number(40),
                "height": .number(40),
                "fillKind": .string("linearGradient")
            ]
        ))
        #expect(!missingGradient.ok)

        let perStopAlpha = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillGradient": .object([
                    "startColor": .object([
                        "red": .number(1),
                        "green": .number(0),
                        "blue": .number(0),
                        "alpha": .number(0.5)
                    ]),
                    "endColor": .object([
                        "red": .number(0), "green": .number(0), "blue": .number(1)
                    ])
                ])
            ]
        ))
        #expect(!perStopAlpha.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == nil)

        let unorderedStops = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillGradient": .object([
                    "stops": .array([
                        .object([
                            "position": .number(0),
                            "color": .object([
                                "red": .number(1), "green": .number(0), "blue": .number(0)
                            ])
                        ]),
                        .object([
                            "position": .number(0.8),
                            "color": .object([
                                "red": .number(0), "green": .number(1), "blue": .number(0)
                            ])
                        ]),
                        .object([
                            "position": .number(0.3),
                            "color": .object([
                                "red": .number(0), "green": .number(0), "blue": .number(1)
                            ])
                        ])
                    ])
                ])
            ]
        ))
        #expect(!unorderedStops.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == nil)
    }

    @Test func registryCreatesInspectsAndSwitchesShapeRadialGradient() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("ellipse"),
                "x": .number(10),
                "y": .number(12),
                "width": .number(90),
                "height": .number(70),
                "fillKind": .string("radialGradient"),
                "fillGradient": .object([
                    "startColor": .object([
                        "red": .number(1), "green": .number(0), "blue": .number(0)
                    ]),
                    "endColor": .object([
                        "red": .number(0), "green": .number(0), "blue": .number(1)
                    ]),
                    "scale": .number(0.75),
                    "centerX": .number(0.4),
                    "centerY": .number(0.6)
                ])
            ]
        ))
        #expect(created.ok)
        let content = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(content.fillGradient?.style == .radial)
        #expect(content.fillGradient?.scale == 0.75)
        #expect(content.fillGradientCenter == CGPoint(x: 0.4, y: 0.6))

        let inspected = registry.execute(request(operation: "call", name: "xomo.shape.get"))
        guard case .object(let result) = inspected.result else {
            Issue.record("Expected radial gradient shape result")
            return
        }
        #expect(result["fillKind"] == .string("radialGradient"))

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillGradient": .object([
                    "startColor": .object([
                        "red": .number(1), "green": .number(1), "blue": .number(0)
                    ]),
                    "endColor": .object([
                        "red": .number(0), "green": .number(0), "blue": .number(0)
                    ]),
                    "scale": .number(0.5)
                ])
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.style == .radial)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.scale == 0.5)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["fillKind": .string("linearGradient")]
        )).ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.style == .linear)
        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["fillKind": .string("radialGradient")]
        )).ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.style == .radial)
    }

    @Test func shapeGradientNumericFieldsRejectInvalidValuesAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let baseGradient: [String: XomoJSONValue] = [
            "startColor": .object([
                "red": .number(1), "green": .number(0), "blue": .number(0)
            ]),
            "endColor": .object([
                "red": .number(0), "green": .number(0), "blue": .number(1)
            ])
        ]
        var initialGradient = baseGradient
        initialGradient["angle"] = .number(30)
        initialGradient["scale"] = .number(1.5)
        initialGradient["centerX"] = .number(0.35)
        initialGradient["centerY"] = .number(0.65)
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10), "y": .number(12),
                "width": .number(90), "height": .number(70),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object(initialGradient)
            ]
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count

        for (key, value): (String, XomoJSONValue) in [
            ("angle", .string("30")),
            ("angle", .number(181)),
            ("scale", .bool(true)),
            ("scale", .number(0.24)),
            ("centerX", .string("0.5")),
            ("centerX", .number(-4.01)),
            ("centerY", .bool(false)),
            ("centerY", .number(5.01))
        ] {
            var invalidGradient = baseGradient
            invalidGradient[key] = value
            let invalidUpdate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "fillGradient": .object(invalidGradient),
                    "strokeWidth": .number(12)
                ]
            ))
            #expect(!invalidUpdate.ok)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth != 12)
            #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.angle == 30)

            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(120), "y": .number(12),
                    "width": .number(40), "height": .number(40),
                    "fillGradient": .object(invalidGradient)
                ]
            ))
            #expect(!invalidCreate.ok)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
        }

        var partialCenterGradient = baseGradient
        partialCenterGradient["centerX"] = .number(0.2)
        let partialCenter = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["fillGradient": .object(partialCenterGradient)]
        ))
        #expect(partialCenter.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradientCenter == CGPoint(x: 0.2, y: 0.5))

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let createTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.create")
        })
        let gradientProperties = createTool["inputSchema"]?.objectValue?["properties"]?
            .objectValue?["fillGradient"]?.objectValue?["properties"]?.objectValue
        let expectedBounds: [String: (Double, Double)] = [
            "angle": (-180, 180),
            "scale": (0.25, 4),
            "centerX": (-4, 5),
            "centerY": (-4, 5)
        ]
        for (key, bounds) in expectedBounds {
            #expect(gradientProperties?[key]?.objectValue?["minimum"] == .number(bounds.0))
            #expect(gradientProperties?[key]?.objectValue?["maximum"] == .number(bounds.1))
        }
    }

    @Test func shapeGradientStopsRejectNonArrayValuesAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let colorPair: [String: XomoJSONValue] = [
            "startColor": .object([
                "red": .number(1), "green": .number(0), "blue": .number(0)
            ]),
            "endColor": .object([
                "red": .number(0), "green": .number(0), "blue": .number(1)
            ])
        ]
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10), "y": .number(12),
                "width": .number(90), "height": .number(70),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object(colorPair)
            ]
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableStrokeWidth = viewModel.document.selectedLayer?.shapeContent?.strokeWidth

        for invalidStops: XomoJSONValue in [
            .object([:]),
            .string("0,1"),
            .number(2),
            .bool(false),
            .null
        ] {
            var invalidGradient = colorPair
            invalidGradient["stops"] = invalidStops
            let invalidUpdate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "fillGradient": .object(invalidGradient),
                    "strokeWidth": .number(12)
                ]
            ))
            #expect(!invalidUpdate.ok)
            #expect(invalidUpdate.error?.contains("fillGradient.stops must be an array") == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == stableStrokeWidth)

            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("rectangle"),
                    "x": .number(120), "y": .number(12),
                    "width": .number(40), "height": .number(40),
                    "fillGradient": .object(invalidGradient)
                ]
            ))
            #expect(!invalidCreate.ok)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
        }

        var changedColorPair = colorPair
        changedColorPair["angle"] = .number(15)
        let legacyColorPair = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: ["fillGradient": .object(changedColorPair)]
        ))
        #expect(legacyColorPair.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.shapeColorStops.count == 2)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.angle == 15)
    }

    @Test func shapeGradientStopsRejectLegacyColorConflictsAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let stops: XomoJSONValue = .array([
            .object([
                "position": .number(0),
                "color": .object([
                    "red": .number(1), "green": .number(0), "blue": .number(0)
                ])
            ]),
            .object([
                "position": .number(1),
                "color": .object([
                    "red": .number(0), "green": .number(0), "blue": .number(1)
                ])
            ])
        ])
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10), "y": .number(12),
                "width": .number(90), "height": .number(70),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object(["stops": stops])
            ]
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableStrokeWidth = viewModel.document.selectedLayer?.shapeContent?.strokeWidth

        for conflictingKey in ["startColor", "endColor"] {
            let conflictingGradient: [String: XomoJSONValue] = [
                "stops": stops,
                conflictingKey: .object([
                    "red": .number(0), "green": .number(1), "blue": .number(0)
                ])
            ]
            let invalidUpdate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "fillGradient": .object(conflictingGradient),
                    "strokeWidth": .number(12)
                ]
            ))
            #expect(!invalidUpdate.ok)
            #expect(invalidUpdate.error?.contains("cannot be combined") == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == stableStrokeWidth)

            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("ellipse"),
                    "x": .number(120), "y": .number(12),
                    "width": .number(40), "height": .number(40),
                    "fillGradient": .object(conflictingGradient)
                ]
            ))
            #expect(!invalidCreate.ok)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
        }

        let validStopsUpdate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillGradient": .object([
                    "stops": stops,
                    "angle": .number(20)
                ])
            ]
        ))
        #expect(validStopsUpdate.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.angle == 20)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.shapeColorStops.count == 2)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let createTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.create")
        })
        let stopsDescription = createTool["inputSchema"]?.objectValue?["properties"]?
            .objectValue?["fillGradient"]?.objectValue?["properties"]?
            .objectValue?["stops"]?.objectValue?["description"]?.stringValue
        #expect(stopsDescription?.contains("do not combine with startColor or endColor") == true)
    }

    @Test func shapeGradientStopEntriesReportPreciseAtomicErrors() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let validColor: XomoJSONValue = .object([
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ])
        let terminalStop: XomoJSONValue = .object([
            "position": .number(1),
            "color": validColor
        ])
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10), "y": .number(12),
                "width": .number(90), "height": .number(70),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object([
                    "stops": .array([
                        .object(["position": .number(0), "color": validColor]),
                        terminalStop
                    ])
                ])
            ]
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableStrokeWidth = viewModel.document.selectedLayer?.shapeContent?.strokeWidth
        let invalidEntries: [(XomoJSONValue, String)] = [
            (.string("first"), "fillGradient.stops[0] must be an object"),
            (.object(["color": validColor]), "fillGradient.stops[0].position is required"),
            (
                .object(["position": .string("0"), "color": validColor]),
                "fillGradient.stops[0].position must be a number"
            ),
            (
                .object(["position": .number(-0.01), "color": validColor]),
                "fillGradient.stops[0].position must be between 0 and 1"
            )
        ]

        for (invalidEntry, expectedError) in invalidEntries {
            let invalidGradient: XomoJSONValue = .object([
                "stops": .array([invalidEntry, terminalStop])
            ])
            let invalidUpdate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "fillGradient": invalidGradient,
                    "strokeWidth": .number(12)
                ]
            ))
            #expect(!invalidUpdate.ok)
            #expect(invalidUpdate.error?.contains(expectedError) == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == stableStrokeWidth)

            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("ellipse"),
                    "x": .number(120), "y": .number(12),
                    "width": .number(40), "height": .number(40),
                    "fillGradient": invalidGradient
                ]
            ))
            #expect(!invalidCreate.ok)
            #expect(invalidCreate.error?.contains(expectedError) == true)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
        }
    }

    @Test func shapeGradientStopColorsReportPreciseErrorsAndSchemaBounds() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let validColor: XomoJSONValue = .object([
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ])
        let terminalStop: XomoJSONValue = .object([
            "position": .number(1),
            "color": validColor
        ])
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10), "y": .number(12),
                "width": .number(90), "height": .number(70),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object([
                    "stops": .array([
                        .object(["position": .number(0), "color": validColor]),
                        terminalStop
                    ])
                ])
            ]
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableStrokeWidth = viewModel.document.selectedLayer?.shapeContent?.strokeWidth
        let invalidEntries: [(XomoJSONValue, String)] = [
            (
                .object(["position": .number(0)]),
                "fillGradient.stops[0].color is required"
            ),
            (
                .object(["position": .number(0), "color": .string("red")]),
                "fillGradient.stops[0].color must be an object"
            ),
            (
                .object(["position": .number(0), "color": .null]),
                "fillGradient.stops[0].color must be an object"
            )
        ]

        for (invalidEntry, expectedError) in invalidEntries {
            let invalidGradient: XomoJSONValue = .object([
                "stops": .array([invalidEntry, terminalStop])
            ])
            let invalidUpdate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "fillGradient": invalidGradient,
                    "strokeWidth": .number(12)
                ]
            ))
            #expect(!invalidUpdate.ok)
            #expect(invalidUpdate.error?.contains(expectedError) == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == stableStrokeWidth)

            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("ellipse"),
                    "x": .number(120), "y": .number(12),
                    "width": .number(40), "height": .number(40),
                    "fillGradient": invalidGradient
                ]
            ))
            #expect(!invalidCreate.ok)
            #expect(invalidCreate.error?.contains(expectedError) == true)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
        }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let createTool = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.create")
        })
        let properties = createTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        let fillColorProperties = properties?["fillColor"]?.objectValue?["properties"]?.objectValue
        let stopColorProperties = properties?["fillGradient"]?.objectValue?["properties"]?
            .objectValue?["stops"]?.objectValue?["items"]?.objectValue?["properties"]?
            .objectValue?["color"]?.objectValue?["properties"]?.objectValue
        for component in ["red", "green", "blue"] {
            #expect(fillColorProperties?[component]?.objectValue?["minimum"] == .number(0))
            #expect(fillColorProperties?[component]?.objectValue?["maximum"] == .number(1))
            #expect(stopColorProperties?[component]?.objectValue?["minimum"] == .number(0))
            #expect(stopColorProperties?[component]?.objectValue?["maximum"] == .number(1))
        }
        #expect(fillColorProperties?["alpha"]?.objectValue?["minimum"] == .number(0))
        #expect(fillColorProperties?["alpha"]?.objectValue?["maximum"] == .number(1))
        #expect(stopColorProperties?["alpha"]?.objectValue?["minimum"] == .number(1))
        #expect(stopColorProperties?["alpha"]?.objectValue?["maximum"] == .number(1))
    }

    @Test func shapeGradientStopColorComponentsReportIndexedAtomicErrors() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let validColor: XomoJSONValue = .object([
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ])
        let terminalStop: XomoJSONValue = .object([
            "position": .number(1),
            "color": validColor
        ])
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.shape.create",
            arguments: [
                "kind": .string("rectangle"),
                "x": .number(10), "y": .number(12),
                "width": .number(90), "height": .number(70),
                "fillKind": .string("linearGradient"),
                "fillGradient": .object([
                    "stops": .array([
                        .object(["position": .number(0), "color": validColor]),
                        terminalStop
                    ])
                ])
            ]
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableStrokeWidth = viewModel.document.selectedLayer?.shapeContent?.strokeWidth
        let invalidColors: [(XomoJSONValue, String)] = [
            (
                .object(["green": .number(0), "blue": .number(0)]),
                "fillGradient.stops[0].color.red is required"
            ),
            (
                .object([
                    "red": .number(1), "green": .string("0"), "blue": .number(0)
                ]),
                "fillGradient.stops[0].color.green must be a number"
            ),
            (
                .object([
                    "red": .number(1), "green": .number(0), "blue": .number(1.01)
                ]),
                "fillGradient.stops[0].color.blue must be between 0 and 1"
            ),
            (
                .object([
                    "red": .number(1), "green": .number(0), "blue": .number(0),
                    "alpha": .number(0.5)
                ]),
                "fillGradient.stops[0].color.alpha must be 1"
            )
        ]

        for (invalidColor, expectedError) in invalidColors {
            let invalidGradient: XomoJSONValue = .object([
                "stops": .array([
                    .object(["position": .number(0), "color": invalidColor]),
                    terminalStop
                ])
            ])
            let invalidUpdate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.update",
                arguments: [
                    "fillGradient": invalidGradient,
                    "strokeWidth": .number(12)
                ]
            ))
            #expect(!invalidUpdate.ok)
            #expect(invalidUpdate.error?.contains(expectedError) == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == stableStrokeWidth)

            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.shape.create",
                arguments: [
                    "kind": .string("ellipse"),
                    "x": .number(120), "y": .number(12),
                    "width": .number(40), "height": .number(40),
                    "fillGradient": invalidGradient
                ]
            ))
            #expect(!invalidCreate.ok)
            #expect(invalidCreate.error?.contains(expectedError) == true)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
        }

        let validUpdate = registry.execute(request(
            operation: "call",
            name: "xomo.shape.update",
            arguments: [
                "fillGradient": .object([
                    "stops": .array([
                        .object([
                            "position": .number(0),
                            "color": .object([
                                "red": .number(0), "green": .number(1), "blue": .number(0),
                                "alpha": .number(1)
                            ])
                        ]),
                        terminalStop
                    ])
                ])
            ]
        ))
        #expect(validUpdate.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.shapeColorStops.count == 2)
    }

    @Test func gradientColorSchemasMatchShapeAndFillLayerAlphaSemantics() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let rgb: [String: XomoJSONValue] = [
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ]
        let baseArguments: [String: XomoJSONValue] = [
            "kind": .string("gradientFill"),
            "preset": .string(ImageEditorGradientFillPreset.custom.rawValue),
            "style": .string(ImageEditorGradientFillStyle.linear.rawValue),
            "reverse": .bool(false),
            "angle": .number(0),
            "scale": .number(1),
            "startColor": .object(rgb),
            "endColor": .object(rgb)
        ]
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count

        var alphaStartArguments = baseArguments
        var alphaStart = rgb
        alphaStart["alpha"] = .number(1)
        alphaStartArguments["startColor"] = .object(alphaStart)
        let invalidStart = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: alphaStartArguments
        ))
        #expect(!invalidStart.ok)
        #expect(invalidStart.error?.contains("startColor.alpha is unsupported") == true)
        #expect(viewModel.document.layers.count == stableLayerCount)
        #expect(viewModel.document.history.count == stableHistoryCount)

        var alphaStopArguments = baseArguments
        alphaStopArguments["stops"] = .array([
            .object([
                "position": .number(0),
                "color": .object(alphaStart)
            ]),
            .object([
                "position": .number(1),
                "color": .object(rgb)
            ])
        ])
        let invalidStop = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: alphaStopArguments
        ))
        #expect(!invalidStop.ok)
        #expect(invalidStop.error?.contains("stops[0].color.alpha is unsupported") == true)
        #expect(viewModel.document.layers.count == stableLayerCount)
        #expect(viewModel.document.history.count == stableHistoryCount)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let shapeCreate = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.shape.create")
        })
        let layerCreate = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.layer.create")
        })
        let shapeProperties = shapeCreate["inputSchema"]?.objectValue?["properties"]?.objectValue
        let shapeGradientProperties = shapeProperties?["fillGradient"]?.objectValue?["properties"]?
            .objectValue
        let shapeStartAlpha = shapeGradientProperties?["startColor"]?.objectValue?["properties"]?
            .objectValue?["alpha"]?.objectValue
        let shapeStopAlpha = shapeGradientProperties?["stops"]?.objectValue?["items"]?
            .objectValue?["properties"]?.objectValue?["color"]?.objectValue?["properties"]?
            .objectValue?["alpha"]?.objectValue
        #expect(shapeStartAlpha?["minimum"] == .number(1))
        #expect(shapeStartAlpha?["maximum"] == .number(1))
        #expect(shapeStopAlpha?["minimum"] == .number(1))
        #expect(shapeStopAlpha?["maximum"] == .number(1))

        let layerProperties = layerCreate["inputSchema"]?.objectValue?["properties"]?.objectValue
        let layerStartColorProperties = layerProperties?["startColor"]?.objectValue?["properties"]?
            .objectValue
        let layerStopColorProperties = layerProperties?["stops"]?.objectValue?["items"]?
            .objectValue?["properties"]?.objectValue?["color"]?.objectValue?["properties"]?
            .objectValue
        #expect(layerStartColorProperties?["alpha"] == nil)
        #expect(layerStopColorProperties?["alpha"] == nil)
        #expect(shapeProperties?["fillColor"]?.objectValue?["properties"]?
            .objectValue?["alpha"]?.objectValue?["minimum"] == .number(0))
        #expect(shapeProperties?["fillColor"]?.objectValue?["properties"]?
            .objectValue?["alpha"]?.objectValue?["maximum"] == .number(1))
    }

    @Test func gradientFillGeometrySchemasMatchAtomicRuntimeBounds() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let color: XomoJSONValue = .object([
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ])
        let baseArguments: [String: XomoJSONValue] = [
            "kind": .string("gradientFill"),
            "preset": .string(ImageEditorGradientFillPreset.custom.rawValue),
            "style": .string(ImageEditorGradientFillStyle.linear.rawValue),
            "reverse": .bool(false),
            "angle": .number(0),
            "scale": .number(1),
            "startColor": color,
            "endColor": color,
            "stops": .array([
                .object(["position": .number(0), "color": color]),
                .object(["position": .number(1), "color": color])
            ])
        ]
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let invalidOverrides: [(String, XomoJSONValue, String)] = [
            ("angle", .number(181), "angle must be between -180 and 180"),
            ("scale", .number(0.24), "scale must be between 0.25 and 4"),
            ("angle", .string("0"), "Missing or invalid number argument: angle")
        ]
        for (key, value, expectedError) in invalidOverrides {
            var invalidArguments = baseArguments
            invalidArguments[key] = value
            let response = registry.execute(request(
                operation: "call",
                name: "xomo.layer.create",
                arguments: invalidArguments
            ))
            #expect(!response.ok)
            #expect(response.error?.contains(expectedError) == true)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
        }

        var invalidStopArguments = baseArguments
        invalidStopArguments["stops"] = .array([
            .object(["position": .number(-0.01), "color": color]),
            .object(["position": .number(1), "color": color])
        ])
        let invalidStop = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: invalidStopArguments
        ))
        #expect(!invalidStop.ok)
        #expect(invalidStop.error?.contains("stops[0].position must be between 0 and 1") == true)
        #expect(viewModel.document.layers.count == stableLayerCount)
        #expect(viewModel.document.history.count == stableHistoryCount)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        for toolName in ["xomo.layer.create", "xomo.layer.gradient_fill_settings"] {
            let tool = try #require(tools.compactMap(\.objectValue).first {
                $0["name"] == .string(toolName)
            })
            let properties = tool["inputSchema"]?.objectValue?["properties"]?.objectValue
            #expect(properties?["angle"]?.objectValue?["minimum"] == .number(-180))
            #expect(properties?["angle"]?.objectValue?["maximum"] == .number(180))
            #expect(properties?["scale"]?.objectValue?["minimum"] == .number(0.25))
            #expect(properties?["scale"]?.objectValue?["maximum"] == .number(4))
            let positionSchema = properties?["stops"]?.objectValue?["items"]?
                .objectValue?["properties"]?.objectValue?["position"]?.objectValue
            #expect(positionSchema?["minimum"] == .number(0))
            #expect(positionSchema?["maximum"] == .number(1))
        }
    }

    @Test func gradientFillStopEntriesReportPreciseAtomicErrors() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let color: XomoJSONValue = .object([
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ])
        let terminalStop: XomoJSONValue = .object([
            "position": .number(1), "color": color
        ])
        let baseArguments: [String: XomoJSONValue] = [
            "kind": .string("gradientFill"),
            "preset": .string(ImageEditorGradientFillPreset.custom.rawValue),
            "style": .string(ImageEditorGradientFillStyle.linear.rawValue),
            "reverse": .bool(false),
            "angle": .number(0),
            "scale": .number(1),
            "startColor": color,
            "endColor": color,
            "stops": .array([
                .object(["position": .number(0), "color": color]),
                terminalStop
            ])
        ]
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: baseArguments
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableContent = viewModel.document.selectedLayer?.gradientFillContent?.normalized()
        let invalidEntries: [(XomoJSONValue, String)] = [
            (.string("first"), "stops[0] must be an object"),
            (.object(["color": color]), "stops[0].position is required"),
            (
                .object(["position": .string("0"), "color": color]),
                "stops[0].position must be a number"
            ),
            (
                .object(["position": .number(-0.01), "color": color]),
                "stops[0].position must be between 0 and 1"
            ),
            (.object(["position": .number(0)]), "stops[0].color is required"),
            (
                .object(["position": .number(0), "color": .string("red")]),
                "stops[0].color must be an object"
            )
        ]

        for (invalidEntry, expectedError) in invalidEntries {
            var invalidCreateArguments = baseArguments
            invalidCreateArguments["stops"] = .array([invalidEntry, terminalStop])
            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.layer.create",
                arguments: invalidCreateArguments
            ))
            #expect(!invalidCreate.ok)
            #expect(invalidCreate.error?.contains(expectedError) == true)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)

            var invalidSetArguments = invalidCreateArguments
            invalidSetArguments.removeValue(forKey: "kind")
            invalidSetArguments["action"] = .string("set")
            let invalidSet = registry.execute(request(
                operation: "call",
                name: "xomo.layer.gradient_fill_settings",
                arguments: invalidSetArguments
            ))
            #expect(!invalidSet.ok)
            #expect(invalidSet.error?.contains(expectedError) == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayer?.gradientFillContent?.normalized() == stableContent)
        }
    }

    @Test func gradientFillColorComponentsReportFullAtomicPaths() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let color: XomoJSONValue = .object([
            "red": .number(1), "green": .number(0), "blue": .number(0)
        ])
        let baseArguments: [String: XomoJSONValue] = [
            "kind": .string("gradientFill"),
            "preset": .string(ImageEditorGradientFillPreset.custom.rawValue),
            "style": .string(ImageEditorGradientFillStyle.linear.rawValue),
            "reverse": .bool(false),
            "angle": .number(0),
            "scale": .number(1),
            "startColor": color,
            "endColor": color,
            "stops": .array([
                .object(["position": .number(0), "color": color]),
                .object(["position": .number(1), "color": color])
            ])
        ]
        let created = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: baseArguments
        ))
        #expect(created.ok)
        let stableLayerID = try #require(viewModel.document.selectedLayerID)
        let stableLayerCount = viewModel.document.layers.count
        let stableHistoryCount = viewModel.document.history.count
        let stableContent = viewModel.document.selectedLayer?.gradientFillContent?.normalized()
        let invalidColors: [(String, XomoJSONValue, String)] = [
            (
                "startColor",
                .object(["green": .number(0), "blue": .number(0)]),
                "startColor.red is required"
            ),
            (
                "startColor",
                .object([
                    "red": .number(1), "green": .string("0"), "blue": .number(0)
                ]),
                "startColor.green must be a number"
            ),
            (
                "endColor",
                .object([
                    "red": .number(1), "green": .number(0), "blue": .number(1.01)
                ]),
                "endColor.blue must be between 0 and 1"
            )
        ]

        for (key, invalidColor, expectedError) in invalidColors {
            var invalidCreateArguments = baseArguments
            invalidCreateArguments[key] = invalidColor
            let invalidCreate = registry.execute(request(
                operation: "call",
                name: "xomo.layer.create",
                arguments: invalidCreateArguments
            ))
            #expect(!invalidCreate.ok)
            #expect(invalidCreate.error?.contains(expectedError) == true)
            #expect(viewModel.document.layers.count == stableLayerCount)
            #expect(viewModel.document.history.count == stableHistoryCount)

            var invalidSetArguments = invalidCreateArguments
            invalidSetArguments.removeValue(forKey: "kind")
            invalidSetArguments["action"] = .string("set")
            let invalidSet = registry.execute(request(
                operation: "call",
                name: "xomo.layer.gradient_fill_settings",
                arguments: invalidSetArguments
            ))
            #expect(!invalidSet.ok)
            #expect(invalidSet.error?.contains(expectedError) == true)
            #expect(viewModel.document.history.count == stableHistoryCount)
            #expect(viewModel.document.selectedLayerID == stableLayerID)
            #expect(viewModel.document.selectedLayer?.gradientFillContent?.normalized() == stableContent)
        }

        let invalidStopColor: XomoJSONValue = .object([
            "green": .number(0), "blue": .number(0)
        ])
        var invalidStopArguments = baseArguments
        invalidStopArguments["stops"] = .array([
            .object(["position": .number(0), "color": invalidStopColor]),
            .object(["position": .number(1), "color": color])
        ])
        let invalidStop = registry.execute(request(
            operation: "call",
            name: "xomo.layer.create",
            arguments: invalidStopArguments
        ))
        #expect(!invalidStop.ok)
        #expect(invalidStop.error?.contains("stops[0].color.red is required") == true)
        #expect(viewModel.document.layers.count == stableLayerCount)
        #expect(viewModel.document.history.count == stableHistoryCount)
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
        #expect(project["filename"]?.stringValue?.hasSuffix(".xomoproject") == true)

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
                "paragraphSpacing": .number(18),
                "boxWidth": .number(180),
                "boxHeight": .number(96)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxWidth == 180)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 96)
        #expect(viewModel.document.selectedLayer?.textContent?.paragraphSpacing == 18)
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
                "paragraphSpacing": .number(26),
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
        #expect(viewModel.document.selectedLayer?.textContent?.paragraphSpacing == 26)
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
        #expect(inspectedText["paragraphSpacing"] == .number(26))
        #expect(inspectedText["autoHeight"] == .bool(false))

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

    @Test func registryClampsParagraphSpacingAndUndoRestoresPreviousValue() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("First\nSecond"),
                "boxWidth": .number(160),
                "paragraphSpacing": .number(12)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.paragraphSpacing == 12)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["paragraphSpacing": .number(999)]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.paragraphSpacing == 400)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.textContent?.paragraphSpacing == 12)

        let response = registry.execute(request(operation: "call", name: "xomo.text.get"))
        guard case .object(let result) = response.result else {
            Issue.record("Expected text inspection result")
            return
        }
        #expect(result["paragraphSpacing"] == .number(12))
    }

    @Test func registryControlsTextAutoHeightWithExplicitAutomationSemantics() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool catalog")
            return
        }
        for toolName in ["xomo.text.create", "xomo.text.update"] {
            let tool = try #require(tools.compactMap(\.objectValue).first {
                $0["name"] == .string(toolName)
            })
            #expect(
                tool["inputSchema"]?.objectValue?["properties"]?.objectValue?["autoHeight"]?
                    .objectValue?["type"] == .string("boolean")
            )
        }

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("First\nSecond"),
                "boxWidth": .number(160),
                "autoHeight": .bool(true)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 0)

        var response = registry.execute(request(operation: "call", name: "xomo.text.get"))
        guard case .object(let autoResult) = response.result else {
            Issue.record("Expected auto-height text inspection result")
            return
        }
        #expect(autoResult["autoHeight"] == .bool(true))

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["autoHeight": .bool(false)]
        )).ok)
        let fixedHeight = try #require(viewModel.document.selectedLayer?.textContent?.boxHeight)
        #expect(fixedHeight > 0)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 0)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["autoHeight": .bool(false), "boxHeight": .number(120)]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 120)

        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["autoHeight": .bool(true), "boxHeight": .number(80)]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 120)

        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: ["text": .string("Point"), "autoHeight": .bool(true)]
        ))
        #expect(!response.ok)
    }

    @Test func registryControlsFixedTextOverflowEllipsisAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool catalog")
            return
        }
        for toolName in ["xomo.text.create", "xomo.text.update"] {
            let tool = try #require(tools.compactMap(\.objectValue).first {
                $0["name"] == .string(toolName)
            })
            #expect(
                tool["inputSchema"]?.objectValue?["properties"]?.objectValue?["truncateOverflow"]?
                    .objectValue?["type"] == .string("boolean")
            )
        }

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("One two three four five six"),
                "boxWidth": .number(80),
                "boxHeight": .number(24),
                "truncateOverflow": .bool(true)
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.truncatesOverflow == true)

        var response = registry.execute(request(operation: "call", name: "xomo.text.get"))
        guard case .object(let fixedResult) = response.result else {
            Issue.record("Expected fixed-height text inspection result")
            return
        }
        #expect(fixedResult["truncateOverflow"] == .bool(true))

        let historyCount = viewModel.document.history.count
        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: [
                "autoHeight": .bool(true),
                "truncateOverflow": .bool(true)
            ]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 24)
        #expect(viewModel.document.selectedLayer?.textContent?.truncatesOverflow == true)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["autoHeight": .bool(true)]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 0)
        #expect(viewModel.document.selectedLayer?.textContent?.truncatesOverflow == false)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 24)
        #expect(viewModel.document.selectedLayer?.textContent?.truncatesOverflow == true)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["boxWidth": .number(0)]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.layoutMode == .point)
        #expect(viewModel.document.selectedLayer?.textContent?.truncatesOverflow == false)
        viewModel.undo()

        let layerCount = viewModel.document.layers.count
        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("Point"),
                "truncateOverflow": .bool(true)
            ]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.layers.count == layerCount)
    }

    @Test func registryCreatesReadsAndUpdatesNativeTextCaseAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool catalog")
            return
        }
        let expectedCases = ImageEditorTextCase.allCases.map { XomoJSONValue.string($0.rawValue) }
        for toolName in ["xomo.text.create", "xomo.text.update"] {
            let tool = try #require(tools.compactMap(\.objectValue).first {
                $0["name"] == .string(toolName)
            })
            #expect(
                tool["inputSchema"]?.objectValue?["properties"]?.objectValue?["textCase"]?
                    .objectValue?["enum"] == .array(expectedCases)
            )
        }

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("Continue 继续"),
                "textCase": .string("uppercase")
            ]
        )).ok)
        var content = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(content.text == "Continue 继续")
        #expect(content.textCase == .uppercase)
        #expect(content.displayText == "CONTINUE 继续")

        var response = registry.execute(request(operation: "call", name: "xomo.text.get"))
        guard case .object(let result) = response.result else {
            Issue.record("Expected text inspection result")
            return
        }
        #expect(result["text"] == .string("Continue 继续"))
        #expect(result["textCase"] == .string("uppercase"))
        #expect(result["displayText"] == .string("CONTINUE 继续"))

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: [
                "text": .string("hello world"),
                "textCase": .string("titleCase")
            ]
        )).ok)
        content = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(content.text == "hello world")
        #expect(content.textCase == .titleCase)
        #expect(content.displayText == "Hello World")

        viewModel.undo()
        content = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(content.text == "Continue 继续")
        #expect(content.textCase == .uppercase)

        let historyCount = viewModel.document.history.count
        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["textCase": .string("alternatingCaps")]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.selectedLayer?.textContent?.textCase == .uppercase)
    }

    @Test func registryControlsFixedTextVerticalAlignmentAtomically() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = toolsResponse.result else {
            Issue.record("Expected tool catalog")
            return
        }
        let expectedValues = ImageEditorTextVerticalAlignment.allCases.map {
            XomoJSONValue.string($0.rawValue)
        }
        for toolName in ["xomo.text.create", "xomo.text.update"] {
            let tool = try #require(tools.compactMap(\.objectValue).first {
                $0["name"] == .string(toolName)
            })
            #expect(
                tool["inputSchema"]?.objectValue?["properties"]?.objectValue?["verticalAlignment"]?
                    .objectValue?["enum"] == .array(expectedValues)
            )
        }

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("Aligned"),
                "boxWidth": .number(120),
                "boxHeight": .number(80),
                "verticalAlignment": .string("bottom")
            ]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.verticalAlignment == .bottom)

        var response = registry.execute(request(operation: "call", name: "xomo.text.get"))
        guard case .object(let createdResult) = response.result else {
            Issue.record("Expected text inspection result")
            return
        }
        #expect(createdResult["verticalAlignment"] == .string("bottom"))

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["verticalAlignment": .string("center")]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.verticalAlignment == .center)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.textContent?.verticalAlignment == .bottom)

        let historyCount = viewModel.document.history.count
        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: [
                "autoHeight": .bool(true),
                "verticalAlignment": .string("bottom")
            ]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 80)
        #expect(viewModel.document.selectedLayer?.textContent?.verticalAlignment == .bottom)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["autoHeight": .bool(true)]
        )).ok)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 0)
        #expect(viewModel.document.selectedLayer?.textContent?.verticalAlignment == .top)
        viewModel.undo()

        let layerCount = viewModel.document.layers.count
        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.create",
            arguments: [
                "text": .string("Point"),
                "verticalAlignment": .string("center")
            ]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.layers.count == layerCount)

        let invalidUpdateHistoryCount = viewModel.document.history.count
        response = registry.execute(request(
            operation: "call",
            name: "xomo.text.update",
            arguments: ["verticalAlignment": .string("diagonal")]
        ))
        #expect(!response.ok)
        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == invalidUpdateHistoryCount)
        #expect(viewModel.document.selectedLayer?.textContent?.verticalAlignment == .bottom)
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

    @Test func registryConfiguresSpotHealingModeWithoutASourcePoint() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("healing"),
                "healingMode": .string("spot"),
                "sampleSource": .string("allVisible"),
                "size": .number(10),
                "points": .array([
                    .object(["x": .number(32), "y": .number(32)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.healingBrushMode == .spot)
        #expect(viewModel.healingSourcePoint == nil)
        #expect(viewModel.healingBrushSampleSource == .allVisible)
    }

    @Test func registryConfiguresSpongeDesaturateMode() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryAcceptsASinglePointSpongeDab() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func spongeVibranceAutomationConfiguresAndAdvertisesProtection() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func retouchPressureAutomationAcceptsToneAndSpongeSamplesAndAdvertisesControls() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func smudgePressureAutomationAcceptsSamplesAndSharesRetouchControls() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func blurSharpenPressureAutomationAcceptsSamplesAndSharesRetouchControls() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func sampledBrushPressureAutomationAcceptsCloneAndHealingSamples() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.setBrushPressureControlsSize(false)

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("setCloneSource"),
                "x": .number(12),
                "y": .number(20)
            ]
        )).ok)
        let clone = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("cloneStamp"),
                "pressureSize": .bool(true),
                "pressureSensitivity": .number(80),
                "points": .array([
                    .object([
                        "x": .number(36),
                        "y": .number(32),
                        "pressure": .number(0.25)
                    ])
                ])
            ]
        ))
        #expect(clone.ok)
        #expect(viewModel.retouchPressureControlsSize)
        #expect(viewModel.retouchPressureSensitivity == 80)
        #expect(!viewModel.brushPressureControlsSize)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))

        #expect(registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("setHealingSource"),
                "x": .number(16),
                "y": .number(20)
            ]
        )).ok)
        let healing = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("healing"),
                "pressureSize": .bool(true),
                "points": .array([
                    .object([
                        "x": .number(40),
                        "y": .number(32),
                        "pressure": .number(1)
                    ])
                ])
            ]
        ))
        #expect(healing.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.healingBrush"))
    }

    @Test func spongeFlowAutomationPrefersFlowAndKeepsLegacyOpacity() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let point: XomoJSONValue = .array([
            .object(["x": .number(32), "y": .number(32)])
        ])

        let preferred = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sponge"),
                "flow": .number(0.24),
                "opacity": .number(0.91),
                "points": point
            ]
        ))
        #expect(preferred.ok)
        #expect(abs(viewModel.opacity - 0.24) < 0.001)

        let legacy = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("sponge"),
                "opacity": .number(0.41),
                "points": point
            ]
        ))
        #expect(legacy.ok)
        #expect(abs(viewModel.opacity - 0.41) < 0.001)

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
        #expect(properties["flow"]?.objectValue?["type"] == .string("number"))
    }

    @Test func fingerPaintingAutomationConfiguresSmudgeAndAdvertisesTheOption() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        viewModel.foregroundColor = .systemRed

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("smudge"),
                "fingerPainting": .bool(true),
                "points": .array([
                    .object(["x": .number(20), "y": .number(20)]),
                    .object(["x": .number(36), "y": .number(20)])
                ])
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.smudgeFingerPaintingEnabled)
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
        #expect(properties["fingerPainting"]?.objectValue?["type"] == .string("boolean"))
    }

    @Test func sampleAllLayersAutomationConfiguresSmudgeAndAdvertisesTheOption() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryAcceptsSinglePointDodgeAndBurnDabs() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func registryConfiguresDodgeExposure() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryConfiguresBurnExposure() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryConfiguresAndValidatesDodgeBurnToneRange() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let point: XomoJSONValue = .array([
            .object(["x": .number(32), "y": .number(32)])
        ])

        let shadows = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "toneRange": .string("shadows"),
                "points": point
            ]
        ))
        #expect(shadows.ok)
        #expect(viewModel.toneRange == .shadows)

        let highlights = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("burn"),
                "toneRange": .string("highlights"),
                "points": point
            ]
        ))
        #expect(highlights.ok)
        #expect(viewModel.toneRange == .highlights)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "toneRange": .string("everything"),
                "points": point
            ]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.toneRange == .highlights)
    }

    @Test func registryAdvertisesDodgeBurnToneRangeValues() throws {
        let registry = XomoAutomationRegistry.shared
        registry.register(makeViewModel())
        let response = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = response.result else {
            Issue.record("Expected tool array")
            return
        }
        let specialPaint = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.paint.special")
        })
        let schema = try #require(specialPaint["inputSchema"]?.objectValue)
        let properties = try #require(schema["properties"]?.objectValue)
        let toneRange = try #require(properties["toneRange"]?.objectValue)
        let values = toneRange["enum"]?.arrayValue

        #expect(values == [.string("shadows"), .string("midtones"), .string("highlights")])
    }

    @Test func registryConfiguresDodgeBurnProtectTones() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let point: XomoJSONValue = .array([
            .object(["x": .number(32), "y": .number(32)])
        ])
        #expect(viewModel.protectToneBrushTones)

        let disabled = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("dodge"),
                "protectTones": .bool(false),
                "points": point
            ]
        ))
        #expect(disabled.ok)
        #expect(!viewModel.protectToneBrushTones)

        let enabled = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("burn"),
                "protectTones": .bool(true),
                "points": point
            ]
        ))
        #expect(enabled.ok)
        #expect(viewModel.protectToneBrushTones)
    }

    @Test func registryAdvertisesDodgeBurnProtectTones() throws {
        let registry = XomoAutomationRegistry.shared
        registry.register(makeViewModel())
        let response = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = response.result else {
            Issue.record("Expected tool array")
            return
        }
        let specialPaint = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.paint.special")
        })
        let schema = try #require(specialPaint["inputSchema"]?.objectValue)
        let properties = try #require(schema["properties"]?.objectValue)

        #expect(properties["protectTones"]?.objectValue?["type"] == .string("boolean"))
    }

    @Test func registryConfiguresAndValidatesDodgeBurnAirbrushPulses() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func registryAdvertisesDodgeBurnAirbrushControls() throws {
        let registry = XomoAutomationRegistry.shared
        registry.register(makeViewModel())
        let response = registry.execute(request(operation: "tools"))
        guard case .array(let tools) = response.result else {
            Issue.record("Expected tool array")
            return
        }
        let specialPaint = try #require(tools.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.paint.special")
        })
        let schema = try #require(specialPaint["inputSchema"]?.objectValue)
        let properties = try #require(schema["properties"]?.objectValue)

        #expect(properties["airbrush"]?.objectValue?["type"] == .string("boolean"))
        #expect(properties["airbrushPulses"]?.objectValue?["type"] == .string("integer"))
    }

    @Test func registryKeepsLegacyDodgeOpacity() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryAcceptsSinglePointBlurAndSharpenDabs() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
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

    @Test func registryConfiguresBlurStrength() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryConfiguresSharpenStrength() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryConfiguresSmudgeHardnessAndStrength() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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

    @Test func registryKeepsLegacySmudgeOpacity() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

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
                    .object([
                        "x": .number(12),
                        "y": .number(18),
                        "pressure": .number(0.2),
                        "tiltX": .number(0.25),
                        "tiltY": .number(-0.5)
                    ]),
                    .object([
                        "x": .number(52),
                        "y": .number(18),
                        "pressure": .number(1),
                        "tiltX": .number(1),
                        "tiltY": .number(0)
                    ])
                ]),
                "size": .number(14),
                "opacity": .number(0.75),
                "hardness": .number(0.35),
                "flow": .number(17),
                "spacing": .number(140),
                "pressureSize": .bool(false),
                "pressureOpacity": .bool(true),
                "pressureFlow": .bool(true),
                "pressureSensitivity": .number(72),
                "minimumDiameter": .number(42),
                "minimumOpacity": .number(31),
                "minimumFlow": .number(36),
                "tiltShape": .bool(true),
                "roundness": .number(35),
                "angle": .number(-45),
                "smoothing": .number(75)
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.brushSize == 14)
        #expect(viewModel.opacity == 0.75)
        #expect(viewModel.hardness == 0.35)
        #expect(viewModel.brushFlow == 17)
        #expect(viewModel.brushSpacing == 140)
        #expect(!viewModel.brushPressureControlsSize)
        #expect(viewModel.brushPressureControlsOpacity)
        #expect(viewModel.brushPressureControlsFlow)
        #expect(viewModel.brushPressureSensitivity == 72)
        #expect(viewModel.brushMinimumDiameter == 42)
        #expect(viewModel.brushMinimumOpacity == 31)
        #expect(viewModel.brushMinimumFlow == 36)
        #expect(viewModel.brushTiltControlsShape)
        #expect(viewModel.brushTipRoundness == 35)
        #expect(viewModel.brushTipAngleDegrees == -45)
        #expect(viewModel.brushSmoothing == 75)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.brush"))
    }

    @Test func registryRejectsIncompleteStylusTiltPairsAtomically() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let historyCount = viewModel.document.history.count

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.stroke",
            arguments: [
                "points": .array([
                    .object([
                        "x": .number(12),
                        "y": .number(18),
                        "tiltX": .number(0.5)
                    ])
                ]),
                "tiltShape": .bool(true)
            ]
        ))

        #expect(!response.ok)
        #expect(viewModel.document.history.count == historyCount)
        #expect(!viewModel.brushTiltControlsShape)
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

    @Test func registryRasterizesLayerStylesAndAppliesOnlyVectorMasks() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        viewModel.textValue = "Styled MCP"
        viewModel.addText(at: CGPoint(x: 18, y: 16))
        let textIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[textIndex].style.strokeEnabled = true
        viewModel.document.layers[textIndex].style.strokeWidth = 3
        registry.register(viewModel)

        let rasterize = registry.execute(request(
            operation: "call",
            name: "xomo.layer.rasterize",
            arguments: ["target": .string("layerStyle")]
        ))

        #expect(rasterize.ok)
        let styledRaster = try #require(viewModel.document.selectedLayer)
        #expect(styledRaster.kind.isPixel)
        #expect(!styledRaster.hasLayerEffects)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyleRasterize"))

        let points = [
            CGPoint(x: 2, y: 2),
            CGPoint(x: styledRaster.image.size.width - 2, y: 3),
            CGPoint(x: styledRaster.image.size.width / 2, y: styledRaster.image.size.height - 2)
        ]
        viewModel.document.layers[textIndex].mask = NSImage.transparent(size: styledRaster.image.size)
        viewModel.document.layers[textIndex].vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: points,
            pathAnchors: points.map { ImageEditorPathAnchor(point: $0) },
            isPathClosed: true
        )

        let applyVector = registry.execute(request(
            operation: "call",
            name: "xomo.mask.action",
            arguments: ["action": .string("applyVector")]
        ))

        #expect(applyVector.ok)
        #expect(viewModel.document.selectedLayer?.vectorMask == nil)
        #expect(viewModel.document.selectedLayer?.mask != nil)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskApply"))
    }

    @Test func registryScalesAndTemporarilyHidesLayerEffectsWithoutClearingThem() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style.shadowEnabled = true
        viewModel.document.layers[index].style.shadowBlur = 7
        registry.register(viewModel)

        let scale = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("effectScale"),
                "value": .number(200)
            ]
        ))
        #expect(scale.ok)
        #expect(viewModel.document.layers[index].style.effectScale == 2)
        #expect(viewModel.document.layers[index].style.shadowBlur == 7)

        let hide = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("hideSelected")]
        ))
        #expect(hide.ok)
        #expect(!viewModel.document.layers[index].style.effectsEnabled)
        #expect(viewModel.document.layers[index].style.shadowEnabled)

        let show = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("showAll")]
        ))
        #expect(show.ok)
        #expect(viewModel.document.layers[index].style.effectsEnabled)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerEffectsShowAll"))
    }

    @Test func registryReportsLayerEffectVisibilityCountsAndRejectsNoOps() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].style.strokeEnabled = true
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[secondIndex].style.shadowEnabled = true
        viewModel.document.layers[secondIndex].style.effectsEnabled = false
        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        let initialHistoryCount = viewModel.document.history.count

        let hideSelected = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("hideSelected")]
        ))
        #expect(hideSelected.ok)
        #expect(hideSelected.result?.objectValue?["hiddenLayerCount"] == .number(1))
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        let historyAfterHideSelected = viewModel.document.history.count
        let repeatedHideSelected = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("hideSelected")]
        ))
        #expect(!repeatedHideSelected.ok)
        #expect(viewModel.document.history.count == historyAfterHideSelected)

        let showSelected = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("showSelected")]
        ))
        #expect(showSelected.ok)
        #expect(showSelected.result?.objectValue?["shownLayerCount"] == .number(2))
        let historyAfterShowSelected = viewModel.document.history.count
        let repeatedShowSelected = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("showSelected")]
        ))
        #expect(!repeatedShowSelected.ok)
        #expect(viewModel.document.history.count == historyAfterShowSelected)

        let hideAll = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("hideAll")]
        ))
        #expect(hideAll.ok)
        #expect(hideAll.result?.objectValue?["hiddenLayerCount"] == .number(2))
        let historyAfterHideAll = viewModel.document.history.count
        let repeatedHideAll = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("hideAll")]
        ))
        #expect(!repeatedHideAll.ok)
        #expect(viewModel.document.history.count == historyAfterHideAll)

        let showAll = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("showAll")]
        ))
        #expect(showAll.ok)
        #expect(showAll.result?.objectValue?["shownLayerCount"] == .number(2))
        let historyAfterShowAll = viewModel.document.history.count
        let repeatedShowAll = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("showAll")]
        ))
        #expect(!repeatedShowAll.ok)
        #expect(viewModel.document.history.count == historyAfterShowAll)
    }

    @Test func registryReportsActualLayerStylePasteAndClearCountsAndRejectsNoOps() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let sourceID = try #require(viewModel.document.selectedLayerID)
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[sourceIndex].style.strokeEnabled = true
        viewModel.document.layers[sourceIndex].style.strokeWidth = 7
        let sourceStyle = viewModel.document.layers[sourceIndex].style

        let copy = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("copy")]
        ))
        #expect(copy.ok)
        #expect(copy.result?.objectValue?["copied"] == .bool(true))
        #expect(copy.result?.objectValue?["sourceLayerId"] == .string(sourceID.uuidString))

        viewModel.addLayer()
        let changedID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let matchingID = try #require(viewModel.document.selectedLayerID)
        let matchingIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[matchingIndex].style = sourceStyle
        viewModel.document.selectedLayerID = changedID
        viewModel.document.selectedLayerIDs = [changedID, matchingID]
        let historyBeforePaste = viewModel.document.history.count

        let paste = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("paste")]
        ))
        #expect(paste.ok)
        #expect(paste.result?.objectValue?["pastedLayerCount"] == .number(1))
        #expect(viewModel.document.history.count == historyBeforePaste + 1)

        let historyAfterPaste = viewModel.document.history.count
        let repeatedPaste = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("paste")]
        ))
        #expect(!repeatedPaste.ok)
        #expect(viewModel.document.history.count == historyAfterPaste)

        let clear = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("clear")]
        ))
        #expect(clear.ok)
        #expect(clear.result?.objectValue?["clearedLayerCount"] == .number(2))

        let historyAfterClear = viewModel.document.history.count
        let repeatedClear = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("clear")]
        ))
        #expect(!repeatedClear.ok)
        #expect(viewModel.document.history.count == historyAfterClear)
    }

    @Test func registrySetsLayerStyleStrokePositionWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokePosition = .outside
        second.style.strokeEnabled = true
        second.style.strokePosition = .inside
        locked.style.strokePosition = .outside
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertStrokePositionSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePosition"),
                "position": .string("inside")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokePosition == .inside)
        #expect(viewModel.document.layers[1].style.strokePosition == .inside)
        #expect(viewModel.document.layers[2].style.strokePosition == .outside)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[1].style.strokeEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePosition"),
                "position": .string("inside")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleStrokeWidthAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeWidth = 2
        second.style.strokeEnabled = true
        second.style.strokeWidth = 12
        locked.style.strokeWidth = 4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("strokeWidth", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeWidth"),
                "value": .number(12)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeWidth == 12)
        #expect(viewModel.document.layers[1].style.strokeWidth == 12)
        #expect(viewModel.document.layers[2].style.strokeWidth == 4)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[1].style.strokeEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeWidth"),
                "value": .number(12)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleStrokeOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeOpacity = 0.25
        second.style.strokeEnabled = true
        second.style.strokeOpacity = 0.6
        locked.style.strokeOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("strokeOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeOpacity"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.strokeOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.strokeOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[1].style.strokeEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeOpacity"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeOpacity"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.strokeOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.strokeOpacity == 0.05)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeOpacity"),
                "value": .number(2)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.strokeOpacity == 1)
        #expect(viewModel.document.layers[1].style.strokeOpacity == 1)
        #expect(viewModel.document.layers[2].style.strokeOpacity == 0.4)
    }

    @Test func registrySetsLayerStyleStrokeColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.42, green: 0.18, blue: 0.76, alpha: 1)
        first.style.strokeFillType = .pattern
        first.style.strokeColor = foreground
        second.style.strokeEnabled = true
        second.style.strokeFillType = .color
        second.style.strokeColor = foreground
        locked.style.strokeColor = .systemBlue
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("strokeColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokeFillType == .color)
        #expect(viewModel.document.layers[0].style.strokeColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.strokeColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.strokeColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let replacement = NSColor(srgbRed: 0.9, green: 0.32, blue: 0.1, alpha: 1)
        viewModel.foregroundColor = replacement
        let recolored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeColor")]
        ))
        #expect(recolored.ok)
        #expect(recolored.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.strokeColor.isEqual(replacement))
        #expect(viewModel.document.layers[1].style.strokeColor.isEqual(replacement))
        #expect(viewModel.document.layers[2].style.strokeColor.isEqual(NSColor.systemBlue))
    }

    @Test func registrySetsStrokeGradientEndpointColorsAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.72, green: 0.16, blue: 0.41, alpha: 1)
        let background = NSColor(srgbRed: 0.12, green: 0.68, blue: 0.86, alpha: 1)
        first.style.strokeFillType = .color
        first.style.strokeGradientStartColor = foreground
        second.style.strokeEnabled = true
        second.style.strokeFillType = .gradient
        second.style.strokeGradientStartColor = foreground
        second.style.strokeGradientEndColor = .systemOrange
        locked.style.strokeFillType = .gradient
        locked.style.strokeGradientStartColor = .systemYellow
        locked.style.strokeGradientEndColor = .systemPurple
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        viewModel.backgroundColor = background
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("strokeGradientStartColor", in: toolsResponse)
        try assertLayerStylePropertySchema("strokeGradientEndColor", in: toolsResponse)

        let startResult = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeGradientStartColor")]
        ))
        #expect(startResult.ok)
        #expect(startResult.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokeFillType == .gradient)
        #expect(viewModel.document.layers[0].style.strokeGradientStartColor.isEqual(foreground))
        #expect(viewModel.document.layers[0].style.strokeGradientEndColor.isEqual(background))
        #expect(viewModel.document.layers[1].style.strokeGradientEndColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[2].style.strokeGradientStartColor.isEqual(NSColor.systemYellow))
        #expect(viewModel.document.history.count == historyCount + 1)

        let endResult = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeGradientEndColor")]
        ))
        #expect(endResult.ok)
        #expect(endResult.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeGradientEndColor.isEqual(background))
        #expect(viewModel.document.layers[1].style.strokeGradientEndColor.isEqual(background))
        #expect(viewModel.document.layers[1].style.strokeGradientStartColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.strokeGradientEndColor.isEqual(NSColor.systemPurple))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.count == historyCount + 2)

        let historyAfterEndpoints = viewModel.document.history.count
        let repeatedStart = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeGradientStartColor")]
        ))
        let repeatedEnd = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokeGradientEndColor")]
        ))
        #expect(!repeatedStart.ok)
        #expect(!repeatedEnd.ok)
        #expect(viewModel.document.history.count == historyAfterEndpoints)
    }

    @Test func registrySetsLayerStyleStrokeGradientAngleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeFillType = .color
        first.style.strokeGradientAngle = 120
        second.style.strokeEnabled = true
        second.style.strokeFillType = .gradient
        second.style.strokeGradientAngle = 120
        second.style.strokeGradientStartColor = .systemGreen
        second.style.strokeGradientEndColor = .systemOrange
        locked.style.strokeFillType = .gradient
        locked.style.strokeGradientAngle = 30
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("strokeGradientAngle", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeGradientAngle"),
                "value": .number(480)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeGradientAngle == 120)
        #expect(viewModel.document.layers[1].style.strokeGradientAngle == 120)
        #expect(viewModel.document.layers[2].style.strokeGradientAngle == 30)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokeFillType == .gradient)
        #expect(viewModel.document.layers[0].style.strokeGradientStartColor.isEqual(viewModel.foregroundColor))
        #expect(viewModel.document.layers[0].style.strokeGradientEndColor.isEqual(viewModel.backgroundColor))
        #expect(viewModel.document.layers[1].style.strokeFillType == .gradient)
        #expect(viewModel.document.layers[1].style.strokeGradientStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.strokeGradientEndColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeGradientAngle"),
                "value": .number(120)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.layers[1].style.strokeGradientStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.strokeGradientEndColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleStrokeFillTypeWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeFillType = .color
        second.style.strokeEnabled = true
        second.style.strokeFillType = .pattern
        second.style.strokePatternColor = .systemGreen
        locked.style.strokeFillType = .color
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertStrokeFillTypeSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeFillType"),
                "fillType": .string("pattern")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeFillType == .pattern)
        #expect(viewModel.document.layers[1].style.strokeFillType == .pattern)
        #expect(viewModel.document.layers[2].style.strokeFillType == .color)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeFillType"),
                "fillType": .string("pattern")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleStrokeGradientStyleWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeFillType = .color
        first.style.strokeGradientStyle = .reflected
        second.style.strokeEnabled = true
        second.style.strokeFillType = .gradient
        second.style.strokeGradientStyle = .reflected
        second.style.strokeGradientStartColor = .systemGreen
        second.style.strokeGradientEndColor = .systemOrange
        locked.style.strokeFillType = .color
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertStrokeGradientStyleSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeGradientStyle"),
                "gradientStyle": .string("reflected")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeGradientStyle == .reflected)
        #expect(viewModel.document.layers[0].style.strokeFillType == .gradient)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokeGradientStartColor.isEqual(viewModel.foregroundColor))
        #expect(viewModel.document.layers[0].style.strokeGradientEndColor.isEqual(viewModel.backgroundColor))
        #expect(viewModel.document.layers[1].style.strokeGradientStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.strokeGradientEndColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[2].style.strokeFillType == .color)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokeGradientStyle"),
                "gradientStyle": .string("reflected")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.layers[1].style.strokeGradientStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.strokeGradientEndColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleStrokePatternKindWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeFillType = .color
        first.style.strokePatternKind = .diagonalStripes
        second.style.strokeEnabled = true
        second.style.strokeFillType = .pattern
        second.style.strokePatternKind = .diagonalStripes
        second.style.strokePatternColor = .systemGreen
        locked.style.strokeFillType = .color
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertStrokePatternKindSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternKind"),
                "patternKind": .string("diagonalStripes")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokePatternKind == .diagonalStripes)
        #expect(viewModel.document.layers[0].style.strokeFillType == .pattern)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokePatternColor.isEqual(viewModel.foregroundColor))
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.strokeFillType == .color)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternKind"),
                "patternKind": .string("diagonalStripes")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsStrokePatternColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.76, green: 0.18, blue: 0.43, alpha: 1)
        first.style.strokeFillType = .color
        first.style.strokePatternKind = .checkerboard
        first.style.strokePatternColor = .systemRed
        first.style.strokePatternScale = 10
        second.style.strokeEnabled = true
        second.style.strokeFillType = .pattern
        second.style.strokePatternKind = .dots
        second.style.strokePatternColor = .systemGreen
        second.style.strokePatternScale = 24
        locked.style.strokeFillType = .pattern
        locked.style.strokePatternColor = .systemPurple
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("strokePatternColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokePatternColor")]
        ))
        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokeFillType == .pattern)
        #expect(viewModel.document.layers[0].style.strokePatternColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(foreground))
        #expect(viewModel.document.layers[0].style.strokePatternKind == .checkerboard)
        #expect(viewModel.document.layers[1].style.strokePatternKind == .dots)
        #expect(viewModel.document.layers[0].style.strokePatternScale == 10)
        #expect(viewModel.document.layers[1].style.strokePatternScale == 24)
        #expect(viewModel.document.layers[2].style.strokePatternColor.isEqual(NSColor.systemPurple))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("strokePatternColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleStrokePatternScaleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeFillType = .color
        first.style.strokePatternScale = 64
        second.style.strokeEnabled = true
        second.style.strokeFillType = .pattern
        second.style.strokePatternScale = 64
        second.style.strokePatternColor = .systemGreen
        locked.style.strokeFillType = .pattern
        locked.style.strokePatternScale = 30
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("strokePatternScale", in: toolsResponse)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternScale"),
                "value": .number(80)
            ]
        ))

        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokePatternScale == 64)
        #expect(viewModel.document.layers[0].style.strokeFillType == .pattern)
        #expect(viewModel.document.layers[0].style.strokeEnabled)
        #expect(viewModel.document.layers[0].style.strokePatternColor.isEqual(viewModel.foregroundColor))
        #expect(viewModel.document.layers[1].style.strokePatternScale == 64)
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.strokePatternScale == 30)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterMaximum = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternScale"),
                "value": .number(64)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterMaximum)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternScale"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.strokePatternScale == 6)
        #expect(viewModel.document.layers[1].style.strokePatternScale == 6)
        #expect(viewModel.document.layers[1].style.strokePatternColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.strokePatternScale == 30)
    }

    @Test func registrySetsStrokePatternOffsetsAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.strokeFillType = .color
        first.style.strokePatternKind = .checkerboard
        first.style.strokePatternScale = 10
        first.style.strokePatternOffset = .zero
        second.style.strokeEnabled = true
        second.style.strokeFillType = .pattern
        second.style.strokePatternKind = .dots
        second.style.strokePatternColor = .systemGreen
        second.style.strokePatternScale = 24
        second.style.strokePatternOffset = CGSize(width: 20, height: -10)
        locked.style.strokeFillType = .pattern
        locked.style.strokePatternOffset = CGSize(width: 30, height: 40)
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("strokePatternOffsetX", in: toolsResponse)
        try assertNumericLayerStylePropertySchema("strokePatternOffsetY", in: toolsResponse)

        let horizontal = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternOffsetX"),
                "value": .number(20)
            ]
        ))
        #expect(horizontal.ok)
        #expect(horizontal.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokeFillType == .pattern)
        #expect(viewModel.document.layers[0].style.strokePatternOffset == CGSize(width: 20, height: 0))
        #expect(viewModel.document.layers[1].style.strokePatternOffset == CGSize(width: 20, height: -10))
        #expect(viewModel.document.layers[0].style.strokePatternKind == .checkerboard)
        #expect(viewModel.document.layers[1].style.strokePatternKind == .dots)
        #expect(viewModel.document.layers[0].style.strokePatternScale == 10)
        #expect(viewModel.document.layers[1].style.strokePatternScale == 24)
        #expect(viewModel.document.history.count == historyCount + 1)

        let vertical = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternOffsetY"),
                "value": .number(-10)
            ]
        ))
        #expect(vertical.ok)
        #expect(vertical.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.strokePatternOffset == CGSize(width: 20, height: -10))
        #expect(viewModel.document.layers[1].style.strokePatternOffset == CGSize(width: 20, height: -10))
        #expect(viewModel.document.layers[2].style.strokePatternOffset == CGSize(width: 30, height: 40))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.count == historyCount + 2)

        let historyAfterOffsets = viewModel.document.history.count
        let repeatedX = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternOffsetX"),
                "value": .number(20)
            ]
        ))
        let repeatedY = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("strokePatternOffsetY"),
                "value": .number(-10)
            ]
        ))
        #expect(!repeatedX.ok)
        #expect(!repeatedY.ok)
        #expect(viewModel.document.history.count == historyAfterOffsets)
    }

    @Test func registrySetsMixedInnerGlowSourceWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowSource = .edge
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowSource = .center
        second.style.innerGlowColor = .systemRed
        locked.style.innerGlowSource = .edge
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertInnerGlowSourceSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowSource"),
                "source": .string("center")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowSource == .center)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.layers[2].style.innerGlowSource == .edge)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowSource"),
                "source": .string("center")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let edge = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowSource"),
                "source": .string("edge")
            ]
        ))
        #expect(edge.ok)
        #expect(edge.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowSource == .edge)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .edge)
        #expect(viewModel.document.layers[2].style.innerGlowSource == .edge)
    }

    @Test func registrySetsLayerStyleBevelDirectionWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertBevelDirectionSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelDirection"),
                "bevelDirection": .string("down")
            ]
        ))

        #expect(result.ok)
        #expect(viewModel.document.selectedLayer?.style.bevelDirection == .down)
        #expect(viewModel.document.selectedLayer?.style.bevelEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func registrySetsLayerStyleOuterGlowBlurAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowBlur = 4
        second.style.outerGlowEnabled = true
        second.style.outerGlowBlur = 14
        second.style.outerGlowColor = .systemRed
        locked.style.outerGlowBlur = 9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("outerGlowBlur", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowBlur"),
                "value": .number(14)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 14)
        #expect(viewModel.document.layers[1].style.outerGlowBlur == 14)
        #expect(viewModel.document.layers[2].style.outerGlowBlur == 9)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowBlur"),
                "value": .number(14)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowBlur"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 40)
        #expect(viewModel.document.layers[1].style.outerGlowBlur == 40)
        #expect(viewModel.document.layers[2].style.outerGlowBlur == 9)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleOuterGlowSpreadAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowSpread = 4
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowSpread = 14
        second.style.outerGlowBlur = 19
        second.style.outerGlowColor = .systemRed
        locked.style.outerGlowSpread = 9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("outerGlowSpread", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowSpread"),
                "value": .number(14)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowSpread == 14)
        #expect(viewModel.document.layers[1].style.outerGlowSpread == 14)
        #expect(viewModel.document.layers[2].style.outerGlowSpread == 9)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowBlur == 19)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowSpread"),
                "value": .number(14)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowSpread"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowSpread == 24)
        #expect(viewModel.document.layers[1].style.outerGlowSpread == 24)
        #expect(viewModel.document.layers[2].style.outerGlowSpread == 9)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleOuterGlowNoiseAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowNoise = 0.15
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowNoise = 0.6
        second.style.outerGlowSpread = 8
        second.style.outerGlowColor = .systemRed
        locked.style.outerGlowNoise = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("outerGlowNoise", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowNoise"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowNoise == 0.6)
        #expect(viewModel.document.layers[1].style.outerGlowNoise == 0.6)
        #expect(viewModel.document.layers[2].style.outerGlowNoise == 0.4)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowSpread == 8)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowNoise"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowNoise"),
                "value": .number(10)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowNoise == 1)
        #expect(viewModel.document.layers[1].style.outerGlowNoise == 1)
        #expect(viewModel.document.layers[2].style.outerGlowNoise == 0.4)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleOuterGlowOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowOpacity = 0.2
        second.style.outerGlowEnabled = true
        second.style.outerGlowOpacity = 0.8
        second.style.outerGlowColor = .systemRed
        locked.style.outerGlowOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("outerGlowOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowOpacity"),
                "value": .number(0.8)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowOpacity == 0.8)
        #expect(viewModel.document.layers[1].style.outerGlowOpacity == 0.8)
        #expect(viewModel.document.layers[2].style.outerGlowOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowOpacity"),
                "value": .number(0.8)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowOpacity"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.outerGlowOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerGlowOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowOpacity = 0.2
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowOpacity = 0.8
        second.style.innerGlowChoke = 8
        second.style.innerGlowSource = .center
        second.style.innerGlowColor = .systemRed
        locked.style.innerGlowOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerGlowOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowOpacity"),
                "value": .number(0.8)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowOpacity == 0.8)
        #expect(viewModel.document.layers[1].style.innerGlowOpacity == 0.8)
        #expect(viewModel.document.layers[2].style.innerGlowOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowChoke == 8)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowOpacity"),
                "value": .number(0.8)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowOpacity"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.innerGlowOpacity == 0.05)
        #expect(viewModel.document.layers[2].style.innerGlowOpacity == 0.4)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerGlowColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let targetColor = NSColor(srgbRed: 0.82, green: 0.31, blue: 0.12, alpha: 1)
        first.style.innerGlowColor = .systemRed
        first.style.innerGlowOpacity = 0.35
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowColor = targetColor
        second.style.innerGlowOpacity = 0.72
        second.style.innerGlowBlur = 19
        second.style.innerGlowChoke = 8
        second.style.innerGlowSource = .center
        locked.style.innerGlowColor = .systemBlue
        locked.isLocked = true
        viewModel.foregroundColor = targetColor
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("innerGlowColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("innerGlowColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowColor.isEqual(targetColor))
        #expect(viewModel.document.layers[1].style.innerGlowColor.isEqual(targetColor))
        #expect(viewModel.document.layers[2].style.innerGlowColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[0].style.innerGlowOpacity == 0.35)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowOpacity == 0.72)
        #expect(viewModel.document.layers[1].style.innerGlowBlur == 19)
        #expect(viewModel.document.layers[1].style.innerGlowChoke == 8)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("innerGlowColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleInnerGlowBlurAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowBlur = 4
        first.style.innerGlowOpacity = 0.35
        second.style.innerGlowEnabled = true
        second.style.innerGlowBlur = 14
        second.style.innerGlowChoke = 8
        second.style.innerGlowSource = .center
        second.style.innerGlowColor = .systemRed
        locked.style.innerGlowBlur = 9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerGlowBlur", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowBlur"),
                "value": .number(14)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 14)
        #expect(viewModel.document.layers[1].style.innerGlowBlur == 14)
        #expect(viewModel.document.layers[2].style.innerGlowBlur == 9)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowOpacity == 0.35)
        #expect(viewModel.document.layers[1].style.innerGlowChoke == 8)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowBlur"),
                "value": .number(14)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowBlur"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 40)
        #expect(viewModel.document.layers[1].style.innerGlowBlur == 40)
        #expect(viewModel.document.layers[2].style.innerGlowBlur == 9)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerGlowChokeAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowChoke = 2
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowChoke = 8
        second.style.innerGlowOpacity = 0.72
        second.style.innerGlowSource = .center
        second.style.innerGlowColor = .systemRed
        locked.style.innerGlowChoke = 5
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerGlowChoke", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowChoke"),
                "value": .number(8)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowChoke == 8)
        #expect(viewModel.document.layers[1].style.innerGlowChoke == 8)
        #expect(viewModel.document.layers[2].style.innerGlowChoke == 5)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowOpacity == 0.72)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowChoke"),
                "value": .number(8)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowChoke"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowChoke == 24)
        #expect(viewModel.document.layers[1].style.innerGlowChoke == 24)
        #expect(viewModel.document.layers[2].style.innerGlowChoke == 5)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerGlowNoiseAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowNoise = 0.1
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowNoise = 0.6
        second.style.innerGlowChoke = 8
        second.style.innerGlowSource = .center
        second.style.innerGlowColor = .systemRed
        locked.style.innerGlowNoise = 0.3
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerGlowNoise", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowNoise"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowNoise == 0.6)
        #expect(viewModel.document.layers[1].style.innerGlowNoise == 0.6)
        #expect(viewModel.document.layers[2].style.innerGlowNoise == 0.3)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowChoke == 8)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowNoise"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowNoise"),
                "value": .number(2)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowNoise == 1)
        #expect(viewModel.document.layers[1].style.innerGlowNoise == 1)
        #expect(viewModel.document.layers[2].style.innerGlowNoise == 0.3)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleOuterGlowColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let targetColor = NSColor(srgbRed: 0.82, green: 0.31, blue: 0.12, alpha: 1)
        first.style.outerGlowColor = .systemRed
        first.style.outerGlowOpacity = 0.35
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowColor = targetColor
        second.style.outerGlowOpacity = 0.72
        second.style.outerGlowBlur = 19
        locked.style.outerGlowColor = .systemBlue
        locked.isLocked = true
        viewModel.foregroundColor = targetColor
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("outerGlowColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("outerGlowColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowColor.isEqual(targetColor))
        #expect(viewModel.document.layers[1].style.outerGlowColor.isEqual(targetColor))
        #expect(viewModel.document.layers[2].style.outerGlowColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[0].style.outerGlowOpacity == 0.35)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowOpacity == 0.72)
        #expect(viewModel.document.layers[1].style.outerGlowBlur == 19)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("outerGlowColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleBevelAngleAcrossGlobalAndLocalLight() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelUsesGlobalLight = true
        first.style.bevelAngle = 10
        second.style.bevelUsesGlobalLight = false
        second.style.bevelAngle = -70
        locked.style.bevelUsesGlobalLight = false
        locked.style.bevelAngle = 90
        locked.isLocked = true
        viewModel.document.globalLightAngle = 35
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("bevelAngle", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelAngle"),
                "value": .number(-45)
            ]
        ))

        #expect(result.ok)
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.document.layers[0].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(viewModel.document.layers[1].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(viewModel.document.layers[2].style.bevelAngle == 90)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleShadowAngleAcrossGlobalAndLocalLight() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowUsesGlobalLight = true
        first.style.shadowEnabled = true
        first.style.shadowDistance = 12
        first.style.shadowAngle = 10
        first.style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 12, angle: 35)
        second.style.shadowUsesGlobalLight = false
        second.style.shadowEnabled = true
        second.style.shadowDistance = 20
        second.style.shadowAngle = -45
        second.style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 20, angle: -45)
        locked.style.shadowUsesGlobalLight = false
        locked.style.shadowAngle = 90
        locked.isLocked = true
        viewModel.document.globalLightAngle = 35
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("shadowAngle", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowAngle"),
                "value": .number(-45)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(result.result?.objectValue?["globalLightUpdated"] == .bool(true))
        #expect(viewModel.document.globalLightAngle == -45)
        let firstStyle = viewModel.document.layers[0].style
        let secondStyle = viewModel.document.layers[1].style
        let firstOffset = ImageEditorLayerStyle.shadowOffset(distance: 12, angle: -45)
        let secondOffset = ImageEditorLayerStyle.shadowOffset(distance: 20, angle: -45)
        #expect(firstStyle.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(secondStyle.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(abs(firstStyle.shadowOffset.width - firstOffset.width) < 0.001)
        #expect(abs(firstStyle.shadowOffset.height - firstOffset.height) < 0.001)
        #expect(abs(secondStyle.shadowOffset.width - secondOffset.width) < 0.001)
        #expect(abs(secondStyle.shadowOffset.height - secondOffset.height) < 0.001)
        #expect(viewModel.document.layers[2].style.shadowAngle == 90)
        #expect(viewModel.document.layers[2].style.shadowOffset == CGSize(width: 7, height: -7))
        #expect(firstStyle.shadowEnabled)
        #expect(secondStyle.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowAngle"),
                "value": .number(315)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let changedAgain = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowAngle"),
                "value": .number(-170)
            ]
        ))
        #expect(changedAgain.ok)
        #expect(changedAgain.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(changedAgain.result?.objectValue?["globalLightUpdated"] == .bool(true))
        #expect(viewModel.document.globalLightAngle == -170)
    }

    @Test func registrySetsGlobalLightAngleWithLinkedEffectCounts() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)

        first.style.shadowEnabled = true
        first.style.shadowUsesGlobalLight = true
        first.style.innerShadowEnabled = true
        first.style.innerShadowUsesGlobalLight = true
        second.style.shadowEnabled = true
        second.style.shadowUsesGlobalLight = false
        second.style.bevelEnabled = true
        second.style.bevelUsesGlobalLight = true
        locked.style.shadowEnabled = true
        locked.style.shadowUsesGlobalLight = true
        locked.isLocked = true

        viewModel.document.globalLightAngle = -45
        viewModel.document.layers = [first, second, locked]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("globalLightAngle", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("globalLightAngle"),
                "value": .number(30)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["globalLightUpdated"] == .bool(true))
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(3))
        #expect(result.result?.objectValue?["affectedEffectCount"] == .number(4))
        #expect(result.result?.objectValue?["shadowLayerCount"] == .number(2))
        #expect(result.result?.objectValue?["innerShadowLayerCount"] == .number(1))
        #expect(result.result?.objectValue?["bevelLayerCount"] == .number(1))
        #expect(viewModel.document.globalLightAngle == 30)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("globalLightAngle"),
                "value": .number(390)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleInnerShadowAngleAcrossGlobalAndLocalLight() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowUsesGlobalLight = true
        first.style.innerShadowEnabled = true
        first.style.innerShadowAngle = 10
        first.style.innerShadowColor = .systemRed
        second.style.innerShadowUsesGlobalLight = false
        second.style.innerShadowEnabled = true
        second.style.innerShadowAngle = -70
        second.style.innerShadowColor = .systemGreen
        locked.style.innerShadowUsesGlobalLight = false
        locked.style.innerShadowAngle = 90
        locked.isLocked = true
        viewModel.document.globalLightAngle = 35
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let firstColor = ImageEditorProjectColor(color: first.style.innerShadowColor)
        let secondColor = ImageEditorProjectColor(color: second.style.innerShadowColor)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerShadowAngle", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowAngle"),
                "value": .number(-45)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(result.result?.objectValue?["globalLightUpdated"] == .bool(true))
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.document.layers[0].style.resolvedInnerShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(viewModel.document.layers[1].style.resolvedInnerShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(viewModel.document.layers[2].style.innerShadowAngle == 90)
        #expect(ImageEditorProjectColor(color: viewModel.document.layers[0].style.innerShadowColor) == firstColor)
        #expect(ImageEditorProjectColor(color: viewModel.document.layers[1].style.innerShadowColor) == secondColor)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowAngle"),
                "value": .number(315)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleInnerShadowDistanceAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowDistance = 6
        second.style.innerShadowEnabled = true
        second.style.innerShadowDistance = 24
        second.style.innerShadowColor = .systemRed
        locked.style.innerShadowDistance = 12
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerShadowDistance", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowDistance"),
                "value": .number(24)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerShadowDistance == 24)
        #expect(viewModel.document.layers[1].style.innerShadowDistance == 24)
        #expect(viewModel.document.layers[2].style.innerShadowDistance == 12)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowDistance"),
                "value": .number(24)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowDistance"),
                "value": .number(-20)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowDistance == 0)
        #expect(viewModel.document.layers[1].style.innerShadowDistance == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowDistance"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowDistance == 48)
        #expect(viewModel.document.layers[1].style.innerShadowDistance == 48)
        #expect(viewModel.document.layers[2].style.innerShadowDistance == 12)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerShadowNoiseAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowNoise = 0.15
        second.style.innerShadowEnabled = true
        second.style.innerShadowNoise = 0.6
        second.style.innerShadowColor = .systemRed
        locked.style.innerShadowNoise = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerShadowNoise", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowNoise"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerShadowNoise == 0.6)
        #expect(viewModel.document.layers[1].style.innerShadowNoise == 0.6)
        #expect(viewModel.document.layers[2].style.innerShadowNoise == 0.4)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowNoise"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowNoise"),
                "value": .number(-1)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowNoise == 0)
        #expect(viewModel.document.layers[1].style.innerShadowNoise == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowNoise"),
                "value": .number(10)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowNoise == 1)
        #expect(viewModel.document.layers[1].style.innerShadowNoise == 1)
        #expect(viewModel.document.layers[2].style.innerShadowNoise == 0.4)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerShadowChokeAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowChoke = 2
        second.style.innerShadowEnabled = true
        second.style.innerShadowChoke = 10
        second.style.innerShadowColor = .systemRed
        locked.style.innerShadowChoke = 6
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerShadowChoke", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowChoke"),
                "value": .number(10)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerShadowChoke == 10)
        #expect(viewModel.document.layers[1].style.innerShadowChoke == 10)
        #expect(viewModel.document.layers[2].style.innerShadowChoke == 6)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowChoke"),
                "value": .number(10)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowChoke"),
                "value": .number(-20)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowChoke == 0)
        #expect(viewModel.document.layers[1].style.innerShadowChoke == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowChoke"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowChoke == 24)
        #expect(viewModel.document.layers[1].style.innerShadowChoke == 24)
        #expect(viewModel.document.layers[2].style.innerShadowChoke == 6)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerShadowBlurAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowBlur = 4
        second.style.innerShadowEnabled = true
        second.style.innerShadowBlur = 14
        second.style.innerShadowColor = .systemRed
        locked.style.innerShadowBlur = 9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerShadowBlur", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowBlur"),
                "value": .number(14)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerShadowBlur == 14)
        #expect(viewModel.document.layers[1].style.innerShadowBlur == 14)
        #expect(viewModel.document.layers[2].style.innerShadowBlur == 9)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowBlur"),
                "value": .number(14)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowBlur"),
                "value": .number(-20)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowBlur == 0)
        #expect(viewModel.document.layers[1].style.innerShadowBlur == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowBlur"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowBlur == 40)
        #expect(viewModel.document.layers[1].style.innerShadowBlur == 40)
        #expect(viewModel.document.layers[2].style.innerShadowBlur == 9)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleInnerShadowOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowOpacity = 0.2
        second.style.innerShadowEnabled = true
        second.style.innerShadowOpacity = 0.8
        second.style.innerShadowColor = .systemRed
        locked.style.innerShadowOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("innerShadowOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowOpacity"),
                "value": .number(0.8)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerShadowOpacity == 0.8)
        #expect(viewModel.document.layers[1].style.innerShadowOpacity == 0.8)
        #expect(viewModel.document.layers[2].style.innerShadowOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowOpacity"),
                "value": .number(0.8)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowOpacity"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.innerShadowOpacity == 0.05)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowOpacity"),
                "value": .number(2)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerShadowOpacity == 1)
        #expect(viewModel.document.layers[1].style.innerShadowOpacity == 1)
        #expect(viewModel.document.layers[2].style.innerShadowOpacity == 0.4)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
    }

    @Test func registrySetsLayerStyleShadowDistanceAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowDistance = 6
        first.style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 6, angle: -45)
        second.style.shadowEnabled = true
        second.style.shadowDistance = 24
        second.style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 24, angle: -45)
        locked.style.shadowDistance = 12
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("shadowDistance", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowDistance"),
                "value": .number(24)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowDistance == 24)
        #expect(viewModel.document.layers[1].style.shadowDistance == 24)
        #expect(viewModel.document.layers[2].style.shadowDistance == 12)
        let targetOffset = ImageEditorLayerStyle.shadowOffset(distance: 24, angle: -45)
        #expect(abs(viewModel.document.layers[0].style.shadowOffset.width - targetOffset.width) < 0.001)
        #expect(abs(viewModel.document.layers[0].style.shadowOffset.height - targetOffset.height) < 0.001)
        #expect(abs(viewModel.document.layers[1].style.shadowOffset.width - targetOffset.width) < 0.001)
        #expect(abs(viewModel.document.layers[1].style.shadowOffset.height - targetOffset.height) < 0.001)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowDistance"),
                "value": .number(24)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowDistance"),
                "value": .number(-1)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowDistance == 0)
        #expect(viewModel.document.layers[1].style.shadowDistance == 0)
        #expect(viewModel.document.layers[0].style.shadowOffset == .zero)
        #expect(viewModel.document.layers[1].style.shadowOffset == .zero)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowDistance"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowDistance == 80)
        #expect(viewModel.document.layers[1].style.shadowDistance == 80)
        #expect(viewModel.document.layers[2].style.shadowDistance == 12)
    }

    @Test func registrySetsLayerStyleShadowNoiseAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowNoise = 0.15
        second.style.shadowEnabled = true
        second.style.shadowNoise = 0.6
        locked.style.shadowNoise = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("shadowNoise", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowNoise"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowNoise == 0.6)
        #expect(viewModel.document.layers[1].style.shadowNoise == 0.6)
        #expect(viewModel.document.layers[2].style.shadowNoise == 0.4)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowNoise"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowNoise"),
                "value": .number(-1)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowNoise == 0)
        #expect(viewModel.document.layers[1].style.shadowNoise == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowNoise"),
                "value": .number(2)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowNoise == 1)
        #expect(viewModel.document.layers[1].style.shadowNoise == 1)
        #expect(viewModel.document.layers[2].style.shadowNoise == 0.4)
    }

    @Test func registrySetsLayerStyleShadowSpreadAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowSpread = 2
        second.style.shadowEnabled = true
        second.style.shadowSpread = 10
        locked.style.shadowSpread = 6
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("shadowSpread", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowSpread"),
                "value": .number(10)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowSpread == 10)
        #expect(viewModel.document.layers[1].style.shadowSpread == 10)
        #expect(viewModel.document.layers[2].style.shadowSpread == 6)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowSpread"),
                "value": .number(10)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowSpread"),
                "value": .number(-20)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowSpread == 0)
        #expect(viewModel.document.layers[1].style.shadowSpread == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowSpread"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowSpread == 24)
        #expect(viewModel.document.layers[1].style.shadowSpread == 24)
        #expect(viewModel.document.layers[2].style.shadowSpread == 6)
    }

    @Test func registrySetsLayerStyleShadowBlurAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowBlur = 4
        second.style.shadowEnabled = true
        second.style.shadowBlur = 12
        locked.style.shadowBlur = 9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("shadowBlur", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowBlur"),
                "value": .number(12)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowBlur == 12)
        #expect(viewModel.document.layers[1].style.shadowBlur == 12)
        #expect(viewModel.document.layers[2].style.shadowBlur == 9)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowBlur"),
                "value": .number(12)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowBlur"),
                "value": .number(-20)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowBlur == 0)
        #expect(viewModel.document.layers[1].style.shadowBlur == 0)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowBlur"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowBlur == 30)
        #expect(viewModel.document.layers[1].style.shadowBlur == 30)
        #expect(viewModel.document.layers[2].style.shadowBlur == 9)
    }

    @Test func registrySetsLayerStyleShadowOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowOpacity = 0.25
        second.style.shadowEnabled = true
        second.style.shadowOpacity = 0.6
        locked.style.shadowOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("shadowOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowOpacity"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.shadowOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.shadowOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowOpacity"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowOpacity"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.shadowOpacity == 0.05)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowOpacity"),
                "value": .number(2)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowOpacity == 1)
        #expect(viewModel.document.layers[1].style.shadowOpacity == 1)
        #expect(viewModel.document.layers[2].style.shadowOpacity == 0.4)
    }

    @Test func registrySetsLayerStyleShadowColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.38, green: 0.16, blue: 0.7, alpha: 1)
        first.style.shadowColor = foreground
        second.style.shadowEnabled = true
        second.style.shadowColor = foreground
        locked.style.shadowColor = .systemBlue
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("shadowColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("shadowColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[0].style.shadowColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.shadowColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.shadowColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("shadowColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let replacement = NSColor(srgbRed: 0.84, green: 0.26, blue: 0.08, alpha: 1)
        viewModel.foregroundColor = replacement
        let recolored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("shadowColor")]
        ))
        #expect(recolored.ok)
        #expect(recolored.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.shadowColor.isEqual(replacement))
        #expect(viewModel.document.layers[1].style.shadowColor.isEqual(replacement))
        #expect(viewModel.document.layers[2].style.shadowColor.isEqual(NSColor.systemBlue))
    }

    @Test func registrySetsLayerStyleColorOverlayOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.colorOverlayOpacity = 0.25
        first.style.colorOverlayColor = .systemBlue
        second.style.colorOverlayOpacity = 0.75
        second.style.colorOverlayColor = .systemGreen
        locked.style.colorOverlayOpacity = 0.4
        locked.style.colorOverlayColor = .systemOrange
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("colorOverlayOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("colorOverlayOpacity"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.colorOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.colorOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.colorOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.colorOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.colorOverlayColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.colorOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.colorOverlayEnabled)
        #expect(viewModel.document.layers[1].style.colorOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("colorOverlayOpacity"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleColorOverlayColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.68, green: 0.24, blue: 0.82, alpha: 1)
        first.style.colorOverlayColor = foreground
        first.style.colorOverlayOpacity = 0.25
        second.style.colorOverlayEnabled = true
        second.style.colorOverlayColor = .systemGreen
        second.style.colorOverlayOpacity = 0.75
        locked.style.colorOverlayColor = .systemOrange
        locked.style.colorOverlayOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("colorOverlayColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("colorOverlayColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.colorOverlayEnabled)
        #expect(viewModel.document.layers[1].style.colorOverlayEnabled)
        #expect(viewModel.document.layers[0].style.colorOverlayColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.colorOverlayColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.colorOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.colorOverlayOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.colorOverlayOpacity == 0.75)
        #expect(viewModel.document.layers[2].style.colorOverlayOpacity == 0.4)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("colorOverlayColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let replacement = NSColor(srgbRed: 0.12, green: 0.78, blue: 0.44, alpha: 1)
        viewModel.foregroundColor = replacement
        let recolored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("colorOverlayColor")]
        ))
        #expect(recolored.ok)
        #expect(recolored.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.colorOverlayColor.isEqual(replacement))
        #expect(viewModel.document.layers[1].style.colorOverlayColor.isEqual(replacement))
        #expect(viewModel.document.layers[2].style.colorOverlayColor.isEqual(NSColor.systemOrange))
    }

    @Test func registrySetsLayerStyleGradientOverlayOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayOpacity = 0.25
        first.style.gradientOverlayStartColor = .systemBlue
        first.style.gradientOverlayEndColor = .systemYellow
        second.style.gradientOverlayOpacity = 0.75
        second.style.gradientOverlayStartColor = .systemGreen
        second.style.gradientOverlayEndColor = .systemPink
        locked.style.gradientOverlayOpacity = 0.4
        locked.style.gradientOverlayStartColor = .systemOrange
        locked.style.gradientOverlayEndColor = .systemCyan
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("gradientOverlayOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayOpacity"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.gradientOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.gradientOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.gradientOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.gradientOverlayStartColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[0].style.gradientOverlayEndColor.isEqual(NSColor.systemYellow))
        #expect(viewModel.document.layers[1].style.gradientOverlayStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.gradientOverlayEndColor.isEqual(NSColor.systemPink))
        #expect(viewModel.document.layers[2].style.gradientOverlayStartColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[2].style.gradientOverlayEndColor.isEqual(NSColor.systemCyan))
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayOpacity"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleGradientOverlayColorsAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.76, green: 0.22, blue: 0.48, alpha: 1)
        let background = NSColor(srgbRed: 0.14, green: 0.68, blue: 0.86, alpha: 1)
        first.style.gradientOverlayStartColor = foreground
        first.style.gradientOverlayEndColor = .systemYellow
        second.style.gradientOverlayEnabled = true
        second.style.gradientOverlayStartColor = .systemGreen
        second.style.gradientOverlayEndColor = .systemPink
        locked.style.gradientOverlayStartColor = .systemOrange
        locked.style.gradientOverlayEndColor = .systemCyan
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        viewModel.backgroundColor = background
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("gradientOverlayStartColor", in: toolsResponse)
        try assertLayerStylePropertySchema("gradientOverlayEndColor", in: toolsResponse)

        let startResult = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("gradientOverlayStartColor")]
        ))
        #expect(startResult.ok)
        #expect(startResult.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.gradientOverlayStartColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.gradientOverlayStartColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.gradientOverlayStartColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.gradientOverlayEndColor.isEqual(NSColor.systemYellow))
        #expect(viewModel.document.layers[1].style.gradientOverlayEndColor.isEqual(NSColor.systemPink))
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterStart = viewModel.document.history.count
        let repeatedStart = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("gradientOverlayStartColor")]
        ))
        #expect(!repeatedStart.ok)
        #expect(viewModel.document.history.count == historyAfterStart)

        let endResult = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("gradientOverlayEndColor")]
        ))
        #expect(endResult.ok)
        #expect(endResult.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.gradientOverlayEndColor.isEqual(background))
        #expect(viewModel.document.layers[1].style.gradientOverlayEndColor.isEqual(background))
        #expect(viewModel.document.layers[2].style.gradientOverlayEndColor.isEqual(NSColor.systemCyan))
        #expect(viewModel.document.layers[0].style.gradientOverlayStartColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.gradientOverlayStartColor.isEqual(foreground))
        #expect(viewModel.document.history.count == historyAfterStart + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterEnd = viewModel.document.history.count
        let repeatedEnd = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("gradientOverlayEndColor")]
        ))
        #expect(!repeatedEnd.ok)
        #expect(viewModel.document.history.count == historyAfterEnd)
    }

    @Test func registrySetsLayerStyleGradientOverlayScaleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayScale = 0.5
        first.style.gradientOverlayStartColor = .systemBlue
        first.style.gradientOverlayEndColor = .systemYellow
        second.style.gradientOverlayScale = 2
        second.style.gradientOverlayStartColor = .systemGreen
        second.style.gradientOverlayEndColor = .systemPink
        locked.style.gradientOverlayScale = 1
        locked.style.gradientOverlayStartColor = .systemOrange
        locked.style.gradientOverlayEndColor = .systemCyan
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("gradientOverlayScale", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayScale"),
                "value": .number(1.5)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.gradientOverlayScale == 1.5)
        #expect(viewModel.document.layers[1].style.gradientOverlayScale == 1.5)
        #expect(viewModel.document.layers[2].style.gradientOverlayScale == 1)
        #expect(viewModel.document.layers[0].style.gradientOverlayStartColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[0].style.gradientOverlayEndColor.isEqual(NSColor.systemYellow))
        #expect(viewModel.document.layers[1].style.gradientOverlayStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.gradientOverlayEndColor.isEqual(NSColor.systemPink))
        #expect(viewModel.document.layers[2].style.gradientOverlayStartColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[2].style.gradientOverlayEndColor.isEqual(NSColor.systemCyan))
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayScale"),
                "value": .number(1.5)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleGradientOverlayAngleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayAngle = -45
        first.style.gradientOverlayStartColor = .systemBlue
        first.style.gradientOverlayEndColor = .systemYellow
        second.style.gradientOverlayAngle = 90
        second.style.gradientOverlayStartColor = .systemGreen
        second.style.gradientOverlayEndColor = .systemPink
        locked.style.gradientOverlayAngle = 30
        locked.style.gradientOverlayStartColor = .systemOrange
        locked.style.gradientOverlayEndColor = .systemCyan
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("gradientOverlayAngle", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayAngle"),
                "value": .number(480)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.gradientOverlayAngle == 120)
        #expect(viewModel.document.layers[1].style.gradientOverlayAngle == 120)
        #expect(viewModel.document.layers[2].style.gradientOverlayAngle == 30)
        #expect(viewModel.document.layers[0].style.gradientOverlayStartColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[0].style.gradientOverlayEndColor.isEqual(NSColor.systemYellow))
        #expect(viewModel.document.layers[1].style.gradientOverlayStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.gradientOverlayEndColor.isEqual(NSColor.systemPink))
        #expect(viewModel.document.layers[2].style.gradientOverlayStartColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[2].style.gradientOverlayEndColor.isEqual(NSColor.systemCyan))
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayAngle"),
                "value": .number(-240)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleGradientOverlayStyleWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayStyle = .linear
        first.style.gradientOverlayStartColor = .systemBlue
        first.style.gradientOverlayEndColor = .systemYellow
        second.style.gradientOverlayStyle = .radial
        second.style.gradientOverlayStartColor = .systemGreen
        second.style.gradientOverlayEndColor = .systemPink
        locked.style.gradientOverlayStyle = .linear
        locked.style.gradientOverlayStartColor = .systemOrange
        locked.style.gradientOverlayEndColor = .systemCyan
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertGradientOverlayStyleSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayStyle"),
                "gradientOverlayStyle": .string("diamond")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.gradientOverlayStyle == .diamond)
        #expect(viewModel.document.layers[1].style.gradientOverlayStyle == .diamond)
        #expect(viewModel.document.layers[2].style.gradientOverlayStyle == .linear)
        #expect(viewModel.document.layers[0].style.gradientOverlayStartColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[0].style.gradientOverlayEndColor.isEqual(NSColor.systemYellow))
        #expect(viewModel.document.layers[1].style.gradientOverlayStartColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[1].style.gradientOverlayEndColor.isEqual(NSColor.systemPink))
        #expect(viewModel.document.layers[2].style.gradientOverlayStartColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[2].style.gradientOverlayEndColor.isEqual(NSColor.systemCyan))
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("gradientOverlayStyle"),
                "gradientOverlayStyle": .string("diamond")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStylePatternOverlayKindWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.patternOverlayKind = .checkerboard
        first.style.patternOverlayColor = .systemBlue
        first.style.patternOverlayOpacity = 0.25
        first.style.patternOverlayScale = 8
        second.style.patternOverlayKind = .dots
        second.style.patternOverlayColor = .systemGreen
        second.style.patternOverlayOpacity = 0.75
        second.style.patternOverlayScale = 24
        locked.style.patternOverlayKind = .checkerboard
        locked.style.patternOverlayColor = .systemOrange
        locked.style.patternOverlayOpacity = 0.4
        locked.style.patternOverlayScale = 12
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertPatternOverlayKindSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayKind"),
                "patternOverlayKind": .string("diagonalStripes")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayKind == .diagonalStripes)
        #expect(viewModel.document.layers[1].style.patternOverlayKind == .diagonalStripes)
        #expect(viewModel.document.layers[2].style.patternOverlayKind == .checkerboard)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.patternOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.75)
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 8)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 24)
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[1].style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayKind"),
                "patternOverlayKind": .string("diagonalStripes")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStylePatternOverlayColorAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.74, green: 0.2, blue: 0.52, alpha: 1)
        first.style.patternOverlayColor = foreground
        first.style.patternOverlayKind = .checkerboard
        first.style.patternOverlayOpacity = 0.25
        first.style.patternOverlayScale = 8
        second.style.patternOverlayEnabled = true
        second.style.patternOverlayColor = .systemGreen
        second.style.patternOverlayKind = .diagonalStripes
        second.style.patternOverlayOpacity = 0.75
        second.style.patternOverlayScale = 24
        locked.style.patternOverlayColor = .systemOrange
        locked.style.patternOverlayKind = .dots
        locked.style.patternOverlayOpacity = 0.4
        locked.style.patternOverlayScale = 12
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertLayerStylePropertySchema("patternOverlayColor", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("patternOverlayColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[1].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.patternOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.patternOverlayKind == .checkerboard)
        #expect(viewModel.document.layers[1].style.patternOverlayKind == .diagonalStripes)
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.75)
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 8)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 24)
        #expect(viewModel.document.layers[2].style.patternOverlayScale == 12)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("patternOverlayColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let replacement = NSColor(srgbRed: 0.14, green: 0.76, blue: 0.42, alpha: 1)
        viewModel.foregroundColor = replacement
        let recolored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("patternOverlayColor")]
        ))
        #expect(recolored.ok)
        #expect(recolored.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(replacement))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(replacement))
        #expect(viewModel.document.layers[2].style.patternOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.patternOverlayKind == .checkerboard)
        #expect(viewModel.document.layers[1].style.patternOverlayKind == .diagonalStripes)
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 24)
    }

    @Test func registrySetsLayerStylePatternOverlayScaleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.patternOverlayScale = 8
        first.style.patternOverlayColor = .systemBlue
        first.style.patternOverlayOpacity = 0.25
        second.style.patternOverlayEnabled = true
        second.style.patternOverlayScale = 32
        second.style.patternOverlayColor = .systemGreen
        second.style.patternOverlayOpacity = 0.75
        locked.style.patternOverlayScale = 12
        locked.style.patternOverlayColor = .systemOrange
        locked.style.patternOverlayOpacity = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("patternOverlayScale", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayScale"),
                "value": .number(32)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 32)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 32)
        #expect(viewModel.document.layers[2].style.patternOverlayScale == 12)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.patternOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.75)
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[1].style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayScale"),
                "value": .number(32)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayScale"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 6)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 6)
        #expect(viewModel.document.layers[2].style.patternOverlayScale == 12)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(NSColor.systemGreen))

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayScale"),
                "value": .number(100)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 64)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 64)
        #expect(viewModel.document.layers[2].style.patternOverlayScale == 12)
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.75)
    }

    @Test func registrySetsPatternOverlayOffsetsAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.patternOverlayKind = .checkerboard
        first.style.patternOverlayScale = 10
        first.style.patternOverlayOffset = .zero
        second.style.patternOverlayEnabled = true
        second.style.patternOverlayKind = .dots
        second.style.patternOverlayColor = .systemGreen
        second.style.patternOverlayScale = 24
        second.style.patternOverlayOffset = CGSize(width: 20, height: -10)
        locked.style.patternOverlayOffset = CGSize(width: 30, height: 40)
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("patternOverlayOffsetX", in: toolsResponse)
        try assertNumericLayerStylePropertySchema("patternOverlayOffsetY", in: toolsResponse)

        let horizontal = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayOffsetX"),
                "value": .number(20)
            ]
        ))
        #expect(horizontal.ok)
        #expect(horizontal.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[0].style.patternOverlayOffset == CGSize(width: 20, height: 0))
        #expect(viewModel.document.layers[1].style.patternOverlayOffset == CGSize(width: 20, height: -10))
        #expect(viewModel.document.layers[0].style.patternOverlayKind == .checkerboard)
        #expect(viewModel.document.layers[1].style.patternOverlayKind == .dots)
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 10)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 24)
        #expect(viewModel.document.history.count == historyCount + 1)

        let vertical = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayOffsetY"),
                "value": .number(-10)
            ]
        ))
        #expect(vertical.ok)
        #expect(vertical.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.patternOverlayOffset == CGSize(width: 20, height: -10))
        #expect(viewModel.document.layers[1].style.patternOverlayOffset == CGSize(width: 20, height: -10))
        #expect(viewModel.document.layers[2].style.patternOverlayOffset == CGSize(width: 30, height: 40))
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.count == historyCount + 2)

        let historyAfterOffsets = viewModel.document.history.count
        for property in ["patternOverlayOffsetX", "patternOverlayOffsetY"] {
            let repeated = registry.execute(request(
                operation: "call",
                name: "xomo.layer.style_settings",
                arguments: [
                    "property": .string(property),
                    "value": .number(property.hasSuffix("X") ? 20 : -10)
                ]
            ))
            #expect(!repeated.ok)
        }
        #expect(viewModel.document.history.count == historyAfterOffsets)
    }

    @Test func registrySetsLayerStylePatternOverlayOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.patternOverlayOpacity = 0.25
        first.style.patternOverlayColor = .systemBlue
        first.style.patternOverlayScale = 8
        second.style.patternOverlayEnabled = true
        second.style.patternOverlayOpacity = 0.6
        second.style.patternOverlayColor = .systemGreen
        second.style.patternOverlayScale = 24
        locked.style.patternOverlayOpacity = 0.4
        locked.style.patternOverlayColor = .systemOrange
        locked.style.patternOverlayScale = 12
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertNumericLayerStylePropertySchema("patternOverlayOpacity", in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayOpacity"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.patternOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[2].style.patternOverlayColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 8)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 24)
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[1].style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayOpacity"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayOpacity"),
                "value": .number(0)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.05)
        #expect(viewModel.document.layers[2].style.patternOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(NSColor.systemGreen))

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("patternOverlayOpacity"),
                "value": .number(2)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 1)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 1)
        #expect(viewModel.document.layers[2].style.patternOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.patternOverlayColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.patternOverlayColor.isEqual(NSColor.systemGreen))
    }

    @Test func registrySetsLayerStyleShadowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowContour = .linear
        second.style.shadowEnabled = true
        second.style.shadowContour = .cone
        locked.style.shadowContour = .soft
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertShadowContourSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowContour"),
                "shadowContour": .string("cone")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.shadowContour == .cone)
        #expect(viewModel.document.layers[1].style.shadowContour == .cone)
        #expect(viewModel.document.layers[2].style.shadowContour == .soft)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowContour"),
                "shadowContour": .string("cone")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("shadowContour"),
                "shadowContour": .string("unknown")
            ]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleInnerShadowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowContour = .linear
        second.style.innerShadowEnabled = true
        second.style.innerShadowContour = .ring
        second.style.innerShadowColor = .systemRed
        locked.style.innerShadowContour = .soft
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertInnerShadowContourSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowContour"),
                "innerShadowContour": .string("ring")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerShadowContour == .ring)
        #expect(viewModel.document.layers[1].style.innerShadowContour == .ring)
        #expect(viewModel.document.layers[2].style.innerShadowContour == .soft)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowContour"),
                "innerShadowContour": .string("ring")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerShadowContour"),
                "innerShadowContour": .string("unknown")
            ]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)
    }

    @Test func registrySetsLayerStyleOuterGlowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowContour = .linear
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowContour = .soft
        second.style.outerGlowSpread = 8
        second.style.outerGlowColor = .systemRed
        locked.style.outerGlowContour = .linear
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertOuterGlowContourSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowContour"),
                "outerGlowContour": .string("soft")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowContour == .soft)
        #expect(viewModel.document.layers[1].style.outerGlowContour == .soft)
        #expect(viewModel.document.layers[2].style.outerGlowContour == .linear)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowSpread == 8)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowContour"),
                "outerGlowContour": .string("soft")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let ring = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowContour"),
                "outerGlowContour": .string("ring")
            ]
        ))
        #expect(ring.ok)
        #expect(ring.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowContour == .ring)
        #expect(viewModel.document.layers[1].style.outerGlowContour == .ring)
        #expect(viewModel.document.layers[2].style.outerGlowContour == .linear)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowContour"),
                "outerGlowContour": .string("unknown")
            ]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate + 1)
    }

    @Test func registrySetsLayerStyleOuterGlowRangeWithActualUpdateCount() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowRange = 0.25
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowRange = 0.65
        second.style.outerGlowColor = .systemRed
        second.style.outerGlowContour = .steep
        locked.style.outerGlowRange = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("outerGlowRange")) == true)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowRange"),
                "value": .number(0.65)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowRange == 0.65)
        #expect(viewModel.document.layers[1].style.outerGlowRange == 0.65)
        #expect(viewModel.document.layers[2].style.outerGlowRange == 0.4)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.layers[1].style.outerGlowContour == .steep)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowRange"),
                "value": .number(0.65)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let clamped = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowRange"),
                "value": .number(2)
            ]
        ))
        #expect(clamped.ok)
        #expect(clamped.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowRange == 1)
        #expect(viewModel.document.layers[1].style.outerGlowRange == 1)
        #expect(viewModel.document.layers[2].style.outerGlowRange == 0.4)
    }

    @Test func registrySetsLayerStyleOuterGlowJitterWithActualUpdateCount() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowJitter = 0.1
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowJitter = 0.6
        second.style.outerGlowColor = .systemRed
        second.style.outerGlowRange = 0.4
        locked.style.outerGlowJitter = 0.3
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("outerGlowJitter")) == true)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowJitter"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowJitter == 0.6)
        #expect(viewModel.document.layers[1].style.outerGlowJitter == 0.6)
        #expect(viewModel.document.layers[2].style.outerGlowJitter == 0.3)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.layers[1].style.outerGlowRange == 0.4)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowJitter"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let clamped = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowJitter"),
                "value": .number(2)
            ]
        ))
        #expect(clamped.ok)
        #expect(clamped.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.outerGlowJitter == 1)
        #expect(viewModel.document.layers[1].style.outerGlowJitter == 1)
        #expect(viewModel.document.layers[2].style.outerGlowJitter == 0.3)
    }

    @Test func registrySetsLayerStyleOuterGlowTechniqueWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowTechnique = .softer
        first.style.outerGlowBlur = 7
        second.style.outerGlowEnabled = true
        second.style.outerGlowTechnique = .precise
        second.style.outerGlowColor = .systemRed
        locked.style.outerGlowTechnique = .softer
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let techniqueSchema = try #require(properties["outerGlowTechnique"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("outerGlowTechnique")) == true)
        #expect(techniqueSchema["enum"] == .array([.string("softer"), .string("precise")]))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowTechnique"),
                "outerGlowTechnique": .string("precise")
            ]
        ))
        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.outerGlowTechnique == .precise)
        #expect(viewModel.document.layers[1].style.outerGlowTechnique == .precise)
        #expect(viewModel.document.layers[2].style.outerGlowTechnique == .softer)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.outerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)

        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowTechnique"),
                "outerGlowTechnique": .string("precise")
            ]
        ))
        #expect(!repeated.ok)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("outerGlowTechnique"),
                "outerGlowTechnique": .string("unknown")
            ]
        ))
        #expect(!invalid.ok)
    }

    @Test func registrySetsLayerStyleInnerGlowTechniqueWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowTechnique = .softer
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowTechnique = .precise
        second.style.innerGlowColor = .systemRed
        locked.style.innerGlowTechnique = .softer
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let techniqueSchema = try #require(properties["innerGlowTechnique"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("innerGlowTechnique")) == true)
        #expect(techniqueSchema["enum"] == .array([.string("softer"), .string("precise")]))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowTechnique"),
                "innerGlowTechnique": .string("precise")
            ]
        ))
        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowTechnique == .precise)
        #expect(viewModel.document.layers[1].style.innerGlowTechnique == .precise)
        #expect(viewModel.document.layers[2].style.innerGlowTechnique == .softer)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.history.count == historyCount + 1)

        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowTechnique"),
                "innerGlowTechnique": .string("precise")
            ]
        ))
        #expect(!repeated.ok)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowTechnique"),
                "innerGlowTechnique": .string("unknown")
            ]
        ))
        #expect(!invalid.ok)
    }

    @Test func registrySetsLayerStyleInnerGlowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowContour = .linear
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowContour = .soft
        second.style.innerGlowColor = .systemRed
        second.style.innerGlowSource = .center
        locked.style.innerGlowContour = .linear
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertInnerGlowContourSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowContour"),
                "innerGlowContour": .string("soft")
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowContour == .soft)
        #expect(viewModel.document.layers[1].style.innerGlowContour == .soft)
        #expect(viewModel.document.layers[2].style.innerGlowContour == .linear)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.layers[1].style.innerGlowSource == .center)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowContour"),
                "innerGlowContour": .string("soft")
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let ring = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowContour"),
                "innerGlowContour": .string("ring")
            ]
        ))
        #expect(ring.ok)
        #expect(ring.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowContour == .ring)
        #expect(viewModel.document.layers[1].style.innerGlowContour == .ring)
        #expect(viewModel.document.layers[2].style.innerGlowContour == .linear)

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowContour"),
                "innerGlowContour": .string("unknown")
            ]
        ))
        #expect(!invalid.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate + 1)
    }

    @Test func registrySetsLayerStyleInnerGlowRangeWithActualUpdateCount() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowRange = 0.25
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowRange = 0.65
        second.style.innerGlowColor = .systemRed
        second.style.innerGlowContour = .steep
        locked.style.innerGlowRange = 0.4
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("innerGlowRange")) == true)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowRange"),
                "value": .number(0.65)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowRange == 0.65)
        #expect(viewModel.document.layers[1].style.innerGlowRange == 0.65)
        #expect(viewModel.document.layers[2].style.innerGlowRange == 0.4)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.layers[1].style.innerGlowContour == .steep)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowRange"),
                "value": .number(0.65)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let clamped = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowRange"),
                "value": .number(2)
            ]
        ))
        #expect(clamped.ok)
        #expect(clamped.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowRange == 1)
        #expect(viewModel.document.layers[1].style.innerGlowRange == 1)
        #expect(viewModel.document.layers[2].style.innerGlowRange == 0.4)
    }

    @Test func registrySetsLayerStyleInnerGlowJitterWithActualUpdateCount() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerGlowJitter = 0.1
        first.style.innerGlowBlur = 7
        second.style.innerGlowEnabled = true
        second.style.innerGlowJitter = 0.6
        second.style.innerGlowColor = .systemRed
        second.style.innerGlowRange = 0.4
        locked.style.innerGlowJitter = 0.3
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("innerGlowJitter")) == true)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowJitter"),
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.innerGlowJitter == 0.6)
        #expect(viewModel.document.layers[1].style.innerGlowJitter == 0.6)
        #expect(viewModel.document.layers[2].style.innerGlowJitter == 0.3)
        #expect(viewModel.document.layers[0].style.innerGlowEnabled)
        #expect(viewModel.document.layers[1].style.innerGlowEnabled)
        #expect(viewModel.document.layers[0].style.innerGlowBlur == 7)
        #expect(viewModel.document.layers[1].style.innerGlowColor == .systemRed)
        #expect(viewModel.document.layers[1].style.innerGlowRange == 0.4)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowJitter"),
                "value": .number(0.6)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let clamped = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("innerGlowJitter"),
                "value": .number(2)
            ]
        ))
        #expect(clamped.ok)
        #expect(clamped.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.innerGlowJitter == 1)
        #expect(viewModel.document.layers[1].style.innerGlowJitter == 1)
        #expect(viewModel.document.layers[2].style.innerGlowJitter == 0.3)
    }

    @Test func registrySetsLayerStyleSatinContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        try assertSatinContourSchema(in: toolsResponse)

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("satinContour"),
                "satinContour": .string("ring")
            ]
        ))

        #expect(result.ok)
        #expect(viewModel.document.selectedLayer?.style.satinContour == .ring)
        #expect(viewModel.document.selectedLayer?.style.satinEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func registryCreatesAppliesListsAndDeletesPersistedLayerStylePresets() throws {
        let suiteName = "XomoAutomationTests.layerStylePresets.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(preferencesDefaults: defaults)
        let registry = XomoAutomationRegistry.shared
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style.strokeEnabled = true
        viewModel.document.layers[index].style.strokeWidth = 8
        viewModel.document.layers[index].style.outerGlowEnabled = true
        viewModel.document.layers[index].style.effectScale = 1.5
        registry.register(viewModel)

        let create = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetCreate"),
                "name": .string("MCP Neon")
            ]
        ))
        #expect(create.ok)
        let created = try #require(create.result?.arrayValue?.first?.objectValue)
        let id = try #require(created["id"]?.stringValue)
        #expect(created["title"] == .string("MCP Neon"))
        #expect(created["active"] == .bool(true))
        #expect(created["effectScale"] == .number(150))

        viewModel.clearSelectedLayerStyles()
        let apply = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetApply"), "id": .string(id)]
        ))
        #expect(apply.ok)
        #expect(viewModel.document.layers[index].style.strokeEnabled)
        #expect(viewModel.document.layers[index].style.strokeWidth == 8)
        #expect(viewModel.document.layers[index].style.outerGlowEnabled)
        #expect(viewModel.document.layers[index].style.effectScale == 1.5)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStylePresetApply"))

        let reopened = makeViewModel(preferencesDefaults: defaults)
        registry.register(reopened)
        let list = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetList")]
        ))
        #expect(list.ok)
        #expect(list.result?.arrayValue?.first?.objectValue?["id"] == .string(id))

        let delete = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetDelete"), "id": .string(id)]
        ))
        #expect(delete.ok)
        #expect(delete.result?.arrayValue?.isEmpty == true)
        #expect(reopened.customLayerStylePresets.isEmpty)
    }

    @Test func registryListsAppliesAndDuplicatesBuiltInLayerStylePresets() throws {
        let suiteName = "XomoAutomationTests.builtInLayerStylePresets.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(preferencesDefaults: defaults)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let catalog = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetCatalog")]
        ))
        #expect(catalog.ok)
        let builtIns = try #require(catalog.result?.arrayValue)
        #expect(builtIns.count == 6)
        #expect(builtIns.allSatisfy { $0.objectValue?["builtIn"] == .bool(true) })
        let id = try #require(builtIns.first?.objectValue?["id"]?.stringValue)

        let apply = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetApply"), "id": .string(id)]
        ))
        #expect(apply.ok)
        #expect(viewModel.document.selectedLayer?.style.hasConfiguredEffects == true)
        #expect(viewModel.activeLayerStylePreset?.id == id)
        let historyCount = viewModel.document.history.count

        let duplicate = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetDuplicate"), "id": .string(id)]
        ))
        #expect(duplicate.ok)
        let custom = try #require(duplicate.result?.arrayValue)
        #expect(custom.count == 1)
        #expect(custom.first?.objectValue?["builtIn"] == .bool(false))
        #expect(custom.first?.objectValue?["id"] != .string(id))
        #expect(viewModel.customLayerStylePresets.first?.style == viewModel.builtInLayerStylePresets.first?.style)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func registryFavoritesAndListsRecentLayerStylePresets() throws {
        let suiteName = "XomoAutomationTests.layerStylePresetUsage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(preferencesDefaults: defaults)
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        let id = try #require(viewModel.builtInLayerStylePresets.first?.id)

        let favorite = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetFavorite"),
                "id": .string(id),
                "favorite": .bool(true)
            ]
        ))
        #expect(favorite.ok)
        #expect(favorite.result?.arrayValue?.first?.objectValue?["id"] == .string(id))
        #expect(favorite.result?.arrayValue?.first?.objectValue?["favorite"] == .bool(true))

        let apply = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetApply"), "id": .string(id)]
        ))
        #expect(apply.ok)

        let reopened = makeViewModel(preferencesDefaults: defaults)
        registry.register(reopened)
        let favorites = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetFavorites")]
        ))
        let recent = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: ["action": .string("presetRecent")]
        ))

        #expect(favorites.ok)
        #expect(favorites.result?.arrayValue?.first?.objectValue?["id"] == .string(id))
        #expect(recent.ok)
        #expect(recent.result?.arrayValue?.first?.objectValue?["id"] == .string(id))
        #expect(recent.result?.arrayValue?.first?.objectValue?["recent"] == .bool(true))
    }

    @Test func registryRenamesMovesExportsAndImportsLayerStylePresetLibraries() throws {
        let suiteName = "XomoAutomationTests.layerStylePresetManager.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(preferencesDefaults: defaults)
        let registry = XomoAutomationRegistry.shared
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style.strokeEnabled = true
        viewModel.document.layers[index].style.strokeWidth = 3
        let first = try #require(viewModel.createLayerStylePresetFromSelectedLayer(name: "First"))
        viewModel.document.layers[index].style.strokeWidth = 8
        let second = try #require(viewModel.createLayerStylePresetFromSelectedLayer(name: "Second"))
        registry.register(viewModel)

        let rename = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetRename"),
                "id": .string(first.id),
                "name": .string("Renamed")
            ]
        ))
        #expect(rename.ok)
        #expect(rename.result?.arrayValue?.first?.objectValue?["title"] == .string("Renamed"))

        let move = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetMove"),
                "id": .string(second.id),
                "direction": .string("top")
            ]
        ))
        #expect(move.ok)
        #expect(move.result?.arrayValue?.first?.objectValue?["id"] == .string(second.id))

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-preset-manager-\(UUID().uuidString)")
            .appendingPathExtension("xomostyles")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let export = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetExport"),
                "path": .string(fileURL.path)
            ]
        ))
        #expect(export.ok)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        viewModel.deleteLayerStylePreset(first)
        viewModel.deleteLayerStylePreset(second)
        #expect(viewModel.customLayerStylePresets.isEmpty)

        let previewResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetImportPreview"),
                "path": .string(fileURL.path)
            ]
        ))
        #expect(previewResponse.ok)
        #expect(previewResponse.result?.objectValue?["total"] == .number(2))
        #expect(previewResponse.result?.objectValue?["importable"] == .number(2))
        #expect(previewResponse.result?.objectValue?["duplicates"] == .number(0))
        #expect(previewResponse.result?.objectValue?["capacitySkipped"] == .number(0))
        #expect(previewResponse.result?.objectValue?["items"]?.arrayValue?.count == 2)
        #expect(viewModel.customLayerStylePresets.isEmpty)

        let importResponse = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style",
            arguments: [
                "action": .string("presetImport"),
                "path": .string(fileURL.path)
            ]
        ))
        #expect(importResponse.ok)
        let imported = try #require(importResponse.result?.arrayValue)
        #expect(imported.map { $0.objectValue?["title"]?.stringValue } == ["Second", "Renamed"])
        #expect(imported[0].objectValue?["id"] != .string(second.id))
        #expect(imported[1].objectValue?["id"] != .string(first.id))
        #expect(viewModel.customLayerStylePresets[0].layerStyle.strokeWidth == 8)
        #expect(viewModel.customLayerStylePresets[1].layerStyle.strokeWidth == 3)
    }

    @Test func registrySavesListsRenamesLoadsAndDeletesIndependentPaths() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        [
            CGPoint(x: 12, y: 10),
            CGPoint(x: 74, y: 14),
            CGPoint(x: 44, y: 54)
        ].forEach(viewModel.addPenPoint)
        viewModel.finishPenPath(closed: true)
        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        registry.register(viewModel)

        let save = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("save"), "name": .string("Logo")]
        ))
        let savedID = try #require(save.result?.arrayValue?.first?.objectValue?["id"]?.stringValue)
        #expect(save.ok)
        #expect(save.result?.arrayValue?.first?.objectValue?["title"] == .string("Logo"))
        #expect(save.result?.arrayValue?.first?.objectValue?["selected"] == .bool(true))

        let visibilityHistoryCount = viewModel.document.history.count
        let visibility = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: [
                "action": .string("visibility"),
                "id": .string(savedID),
                "visible": .bool(true)
            ]
        ))
        #expect(visibility.ok)
        #expect(visibility.result?.arrayValue?.first?.objectValue?["visible"] == .bool(true))
        #expect(viewModel.document.history.count == visibilityHistoryCount)

        let rename = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: [
                "action": .string("rename"),
                "id": .string(savedID),
                "name": .string("Logo Outline")
            ]
        ))
        #expect(rename.ok)
        #expect(rename.result?.arrayValue?.first?.objectValue?["title"] == .string("Logo Outline"))

        let duplicate = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("duplicate"), "id": .string(savedID)]
        ))
        let duplicateID = try #require(
            duplicate.result?.arrayValue?.first(where: {
                $0.objectValue?["id"]?.stringValue != savedID
            })?.objectValue?["id"]?.stringValue
        )
        #expect(duplicate.ok)
        #expect(duplicate.result?.arrayValue?.count == 2)
        #expect(duplicate.result?.arrayValue?.first(where: {
            $0.objectValue?["id"]?.stringValue == duplicateID
        })?.objectValue?["selected"] == .bool(true))

        let selection = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("selection"), "id": .string(savedID)]
        ))
        #expect(selection.ok)
        #expect(viewModel.document.selection?.rasterMask != nil)
        viewModel.document.selection = nil

        viewModel.addLayer()
        let targetLayerID = try #require(viewModel.document.selectedLayerID)
        #expect(targetLayerID != sourceLayerID)
        viewModel.foregroundColor = .white
        viewModel.opacity = 1
        let fill = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("fill"), "id": .string(savedID)]
        ))
        #expect(fill.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.savedPathFill"))
        let stroke = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("stroke"), "id": .string(savedID)]
        ))
        #expect(stroke.ok)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.savedPathStroke"))

        viewModel.document.layers.removeAll { $0.id == sourceLayerID }
        let load = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("load"), "id": .string(savedID)]
        ))
        #expect(load.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.kind == .path)
        #expect(viewModel.document.selectedLayer?.name == "Logo Outline")

        let deleteDuplicate = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("delete"), "id": .string(duplicateID)]
        ))
        #expect(deleteDuplicate.ok)

        let delete = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("delete"), "id": .string(savedID)]
        ))
        #expect(delete.ok)
        #expect(delete.result?.arrayValue?.isEmpty == true)
    }

    @Test func registryAdvertisesAndReordersIndependentSavedPaths() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 12, y: 10)),
            ImageEditorPathAnchor(point: CGPoint(x: 74, y: 14)),
            ImageEditorPathAnchor(point: CGPoint(x: 44, y: 54))
        ]]
        let first = ImageEditorSavedPath(name: "First", subpaths: anchors, isClosed: true)
        let second = ImageEditorSavedPath(name: "Second", subpaths: anchors, isClosed: true)
        let third = ImageEditorSavedPath(name: "Third", subpaths: anchors, isClosed: true)
        viewModel.document.savedPaths = [first, second, third]
        registry.register(viewModel)

        let toolsResponse = registry.execute(request(operation: "tools"))
        let tools = try #require(toolsResponse.result?.arrayValue)
        let savedPathTool = try #require(tools.first {
            $0.objectValue?["name"] == .string("xomo.path.saved")
        })
        let advertisedActions = savedPathTool.objectValue?["inputSchema"]?
            .objectValue?["properties"]?
            .objectValue?["action"]?
            .objectValue?["enum"]?
            .arrayValue?
            .compactMap(\.stringValue) ?? []
        #expect(["moveUp", "moveDown", "moveToTop", "moveToBottom"].allSatisfy {
            advertisedActions.contains($0)
        })

        let initialHistoryCount = viewModel.document.history.count
        let moveUp = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("moveUp"), "id": .string(second.id.uuidString)]
        ))
        #expect(moveUp.ok)
        #expect(moveUp.result?.arrayValue?.compactMap { $0.objectValue?["id"]?.stringValue } == [
            second.id.uuidString, first.id.uuidString, third.id.uuidString
        ])
        #expect(viewModel.document.selectedSavedPathID == second.id)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)

        let moveDown = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("moveDown"), "id": .string(second.id.uuidString)]
        ))
        #expect(moveDown.ok)
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, third.id])
        #expect(viewModel.document.history.count == initialHistoryCount + 2)

        let moveToTop = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("moveToTop"), "id": .string(third.id.uuidString)]
        ))
        #expect(moveToTop.ok)
        #expect(viewModel.document.savedPaths.map(\.id) == [third.id, first.id, second.id])
        #expect(viewModel.document.history.count == initialHistoryCount + 3)

        let moveToBottom = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("moveToBottom"), "id": .string(third.id.uuidString)]
        ))
        #expect(moveToBottom.ok)
        #expect(viewModel.document.savedPaths.map(\.id) == [first.id, second.id, third.id])
        #expect(moveToBottom.result?.arrayValue?.compactMap {
            $0.objectValue?["id"]?.stringValue
        } == [first.id.uuidString, second.id.uuidString, third.id.uuidString])
        #expect(viewModel.document.selectedSavedPathID == third.id)
        #expect(viewModel.document.history.count == initialHistoryCount + 4)

        let beforeBoundaryPaths = viewModel.document.savedPaths
        let boundary = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("moveUp"), "id": .string(first.id.uuidString)]
        ))
        #expect(!boundary.ok)
        #expect(boundary.error?.contains("boundary") == true)
        #expect(viewModel.document.savedPaths == beforeBoundaryPaths)
        #expect(viewModel.document.history.count == initialHistoryCount + 4)

        let missing = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("moveDown"), "id": .string(UUID().uuidString)]
        ))
        #expect(!missing.ok)
        #expect(missing.error?.hasPrefix("Not found:") == true)
        #expect(viewModel.document.savedPaths == beforeBoundaryPaths)
        #expect(viewModel.document.history.count == initialHistoryCount + 4)
    }

    @Test func registryReturnsSavedPathIndexesAndMovesToExactIndex() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        let anchors = [[
            ImageEditorPathAnchor(point: CGPoint(x: 12, y: 10)),
            ImageEditorPathAnchor(point: CGPoint(x: 74, y: 14)),
            ImageEditorPathAnchor(point: CGPoint(x: 44, y: 54))
        ]]
        let first = ImageEditorSavedPath(name: "First", subpaths: anchors, isClosed: true)
        let second = ImageEditorSavedPath(name: "Second", subpaths: anchors, isClosed: true)
        let third = ImageEditorSavedPath(name: "Third", subpaths: anchors, isClosed: true)
        let fourth = ImageEditorSavedPath(name: "Fourth", subpaths: anchors, isClosed: true)
        viewModel.document.savedPaths = [first, second, third, fourth]
        registry.register(viewModel)

        let tools = try #require(registry.execute(request(operation: "tools")).result?.arrayValue)
        let savedPathTool = try #require(tools.first {
            $0.objectValue?["name"] == .string("xomo.path.saved")
        })
        let properties = savedPathTool.objectValue?["inputSchema"]?
            .objectValue?["properties"]?.objectValue
        let advertisedActions = properties?["action"]?
            .objectValue?["enum"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(advertisedActions.contains("moveToIndex"))
        #expect(properties?["index"]?.objectValue?["type"] == .string("integer"))

        let list = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: ["action": .string("list")]
        ))
        #expect(list.ok)
        #expect(list.result?.arrayValue?.compactMap {
            $0.objectValue?["index"]?.doubleValue
        } == [0, 1, 2, 3])

        let historyCount = viewModel.document.history.count
        let move = registry.execute(request(
            operation: "call",
            name: "xomo.path.saved",
            arguments: [
                "action": .string("moveToIndex"),
                "id": .string(first.id.uuidString),
                "index": .number(2)
            ]
        ))
        #expect(move.ok)
        #expect(move.result?.arrayValue?.compactMap {
            $0.objectValue?["id"]?.stringValue
        } == [second.id.uuidString, third.id.uuidString, first.id.uuidString, fourth.id.uuidString])
        #expect(move.result?.arrayValue?.compactMap {
            $0.objectValue?["index"]?.doubleValue
        } == [0, 1, 2, 3])
        #expect(viewModel.document.selectedSavedPathID == first.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        let movedPaths = viewModel.document.savedPaths
        for invalidIndex in [2.0, 1.5, -1.0, 4.0] {
            let rejected = registry.execute(request(
                operation: "call",
                name: "xomo.path.saved",
                arguments: [
                    "action": .string("moveToIndex"),
                    "id": .string(first.id.uuidString),
                    "index": .number(invalidIndex)
                ]
            ))
            #expect(!rejected.ok)
            #expect(viewModel.document.savedPaths == movedPaths)
            #expect(viewModel.document.history.count == historyCount + 1)
        }
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

    @Test func registryConfiguresNoncontiguousPaintBucket() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)

        let response = registry.execute(request(
            operation: "call",
            name: "xomo.paint.special",
            arguments: [
                "action": .string("paintBucket"),
                "x": .number(10),
                "y": .number(10),
                "opacity": .number(1),
                "tolerance": .number(0.07),
                "contiguous": .bool(false)
            ]
        ))

        #expect(response.ok)
        #expect(viewModel.tolerance == 0.07)
        #expect(!viewModel.isPaintBucketContiguous)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.paintBucket"))
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

    private func automationTool(
        named name: String,
        in response: XomoAutomationWireResponse
    ) -> [String: XomoJSONValue]? {
        guard case .array(let tools) = response.result else { return nil }
        return tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string(name) }
    }

    private func assertStrokePositionSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let positionSchema = try #require(properties["position"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("strokePosition")) == true)
        #expect(positionSchema["enum"] == .array([
            .string("outside"), .string("center"), .string("inside")
        ]))
    }

    private func assertNumericLayerStylePropertySchema(
        _ property: String,
        in response: XomoAutomationWireResponse
    ) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let valueSchema = try #require(properties["value"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string(property)) == true)
        #expect(valueSchema["type"] == .string("number"))
    }

    private func assertLayerStylePropertySchema(
        _ property: String,
        in response: XomoAutomationWireResponse
    ) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string(property)) == true)
    }

    private func assertStrokeFillTypeSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let fillTypeSchema = try #require(properties["fillType"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("strokeFillType")) == true)
        #expect(fillTypeSchema["enum"] == .array([
            .string("color"), .string("gradient"), .string("pattern")
        ]))
    }

    private func assertStrokeGradientStyleSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let gradientSchema = try #require(properties["gradientStyle"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("strokeGradientStyle")) == true)
        #expect(gradientSchema["enum"] == .array([
            .string("linear"), .string("radial"), .string("reflected"), .string("diamond")
        ]))
    }

    private func assertStrokePatternKindSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let patternSchema = try #require(properties["patternKind"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("strokePatternKind")) == true)
        #expect(patternSchema["enum"] == .array([
            .string("checkerboard"), .string("diagonalStripes"), .string("dots")
        ]))
    }

    private func assertInnerGlowSourceSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let sourceSchema = try #require(properties["source"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("innerGlowSource")) == true)
        #expect(sourceSchema["enum"] == .array([.string("edge"), .string("center")]))
    }

    private func assertBevelDirectionSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let directionSchema = try #require(properties["bevelDirection"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("bevelDirection")) == true)
        #expect(directionSchema["enum"] == .array([.string("up"), .string("down")]))
    }

    private func assertGradientOverlayStyleSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let styleSchema = try #require(properties["gradientOverlayStyle"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("gradientOverlayStyle")) == true)
        #expect(styleSchema["enum"] == .array([
            .string("linear"), .string("radial"), .string("reflected"), .string("diamond")
        ]))
    }

    private func assertPatternOverlayKindSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let kindSchema = try #require(properties["patternOverlayKind"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("patternOverlayKind")) == true)
        #expect(kindSchema["enum"] == .array([
            .string("checkerboard"), .string("diagonalStripes"), .string("dots")
        ]))
    }

    private func assertShadowContourSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let contourSchema = try #require(properties["shadowContour"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("shadowContour")) == true)
        #expect(contourSchema["enum"] == .array([
            .string("linear"), .string("soft"), .string("steep"), .string("cone"), .string("ring")
        ]))
    }

    private func assertInnerShadowContourSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let contourSchema = try #require(properties["innerShadowContour"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("innerShadowContour")) == true)
        #expect(contourSchema["enum"] == .array([
            .string("linear"), .string("soft"), .string("steep"), .string("cone"), .string("ring")
        ]))
    }

    private func assertOuterGlowContourSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let contourSchema = try #require(properties["outerGlowContour"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("outerGlowContour")) == true)
        #expect(contourSchema["enum"] == .array([
            .string("linear"), .string("soft"), .string("steep"), .string("cone"), .string("ring")
        ]))
    }

    private func assertInnerGlowContourSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let contourSchema = try #require(properties["innerGlowContour"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("innerGlowContour")) == true)
        #expect(contourSchema["enum"] == .array([
            .string("linear"), .string("soft"), .string("steep"), .string("cone"), .string("ring")
        ]))
    }

    private func assertSatinContourSchema(in response: XomoAutomationWireResponse) throws {
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: response))
        let inputSchema = try #require(styleTool["inputSchema"]?.objectValue)
        let properties = try #require(inputSchema["properties"]?.objectValue)
        let propertySchema = try #require(properties["property"]?.objectValue)
        let contourSchema = try #require(properties["satinContour"]?.objectValue)
        #expect(propertySchema["enum"]?.arrayValue?.contains(.string("satinContour")) == true)
        #expect(contourSchema["enum"] == .array([
            .string("linear"), .string("soft"), .string("steep"), .string("cone"), .string("ring")
        ]))
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

    private func maskAlpha(_ mask: ImageEditorSelectionMask, x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < mask.width, y < mask.height else { return 0 }
        return mask.alpha[y * mask.width + x]
    }
}
