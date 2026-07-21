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
        #expect(tools.count == 133)
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.layer.list")
        })
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
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.figma.bindings")
        })
        #expect(tools.contains { tool in
            guard case .object(let value) = tool else { return false }
            return value["name"] == .string("xomo.figma.component_properties")
        })
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
                "filter": .string(ImageEditorFilter.pixelate.rawValue),
                "action": .string("addSmartFilter"),
                "settings": .object(["intensity": .number(0.6)])
            ]
        ))
        #expect(configuredAddResponse.ok)
        #expect(configuredAddResponse.result?.objectValue?["addedLayerCount"] == .number(1))
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.count == 1)
        #expect(viewModel.document.layers.first { $0.id == peerID }?.smartFilters.count == 3)

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
        #expect(maskAlpha(mask, x: 22, y: 13) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionBordered", 2))
    }

    @Test func registryAppliesExplicitLayerTransparencyThreshold() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let size = CGSize(width: 20, height: 10)
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
        #expect(response.result?.objectValue?["layerCount"] == .number(1))
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
        #expect(result["layerCount"] == .number(1))
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

        let invalid = registry.execute(request(
            operation: "call",
            name: "xomo.layer.list",
            arguments: ["figmaBindings": .string("linked")]
        ))
        #expect(!invalid.ok)
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
        viewModel.document.layers[0].xomoFigmaComponentProperties = [
            "Label": XomoFigmaComponentProperty(type: "TEXT", value: "Continue"),
            "Enabled": XomoFigmaComponentProperty(type: "BOOLEAN", value: "true")
        ]
        viewModel.document.layers[0].xomoFigmaComponentPropertyDefaults =
            viewModel.document.layers[0].xomoFigmaComponentProperties

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
                "cornerRadius": .number(40),
                "cornerSmoothing": .number(0.5)
            ]
        ))
        #expect(createResponse.ok)
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerRadius == 20)
        #expect(viewModel.document.selectedLayer?.shapeContent?.cornerSmoothing == 0.5)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillOpacity == 0.6)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeOpacity == 0.8)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeWidth == 7)
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

    @Test func registrySetsMixedInnerGlowSourceWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.document.selectedLayer?.style.innerGlowSource == .center)
        #expect(viewModel.document.selectedLayer?.style.innerGlowEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
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
        second.style.outerGlowBlur = 24
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
        #expect(viewModel.document.layers[0].style.outerGlowBlur == 14)
        #expect(viewModel.document.layers[1].style.outerGlowBlur == 14)
        #expect(viewModel.document.layers[2].style.outerGlowBlur == 9)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleOuterGlowOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.outerGlowOpacity = 0.2
        second.style.outerGlowOpacity = 0.8
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
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(viewModel.document.layers[0].style.outerGlowOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.outerGlowOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.outerGlowOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.outerGlowEnabled)
        #expect(viewModel.document.layers[1].style.outerGlowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
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
        first.style.shadowDistance = 12
        first.style.shadowAngle = 10
        second.style.shadowUsesGlobalLight = false
        second.style.shadowDistance = 20
        second.style.shadowAngle = -70
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
    }

    @Test func registrySetsLayerStyleInnerShadowAngleAcrossGlobalAndLocalLight() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowUsesGlobalLight = true
        first.style.innerShadowAngle = 10
        second.style.innerShadowUsesGlobalLight = false
        second.style.innerShadowAngle = -70
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
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.document.layers[0].style.resolvedInnerShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(viewModel.document.layers[1].style.resolvedInnerShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -45)
        #expect(viewModel.document.layers[2].style.innerShadowAngle == 90)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleInnerShadowDistanceAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowDistance = 6
        second.style.innerShadowDistance = 30
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
        #expect(viewModel.document.layers[0].style.innerShadowDistance == 24)
        #expect(viewModel.document.layers[1].style.innerShadowDistance == 24)
        #expect(viewModel.document.layers[2].style.innerShadowDistance == 12)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleInnerShadowNoiseAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowNoise = 0.15
        second.style.innerShadowNoise = 0.8
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
        #expect(viewModel.document.layers[0].style.innerShadowNoise == 0.6)
        #expect(viewModel.document.layers[1].style.innerShadowNoise == 0.6)
        #expect(viewModel.document.layers[2].style.innerShadowNoise == 0.4)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleInnerShadowChokeAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowChoke = 2
        second.style.innerShadowChoke = 18
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
        #expect(viewModel.document.layers[0].style.innerShadowChoke == 10)
        #expect(viewModel.document.layers[1].style.innerShadowChoke == 10)
        #expect(viewModel.document.layers[2].style.innerShadowChoke == 6)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleInnerShadowBlurAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowBlur = 4
        second.style.innerShadowBlur = 24
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
        #expect(viewModel.document.layers[0].style.innerShadowBlur == 14)
        #expect(viewModel.document.layers[1].style.innerShadowBlur == 14)
        #expect(viewModel.document.layers[2].style.innerShadowBlur == 9)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleInnerShadowOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.innerShadowOpacity = 0.2
        second.style.innerShadowOpacity = 0.8
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
                "value": .number(0.6)
            ]
        ))

        #expect(result.ok)
        #expect(viewModel.document.layers[0].style.innerShadowOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.innerShadowOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.innerShadowOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.innerShadowEnabled)
        #expect(viewModel.document.layers[1].style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleShadowDistanceAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowDistance = 6
        second.style.shadowDistance = 30
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
        #expect(viewModel.document.layers[0].style.shadowDistance == 24)
        #expect(viewModel.document.layers[1].style.shadowDistance == 24)
        #expect(viewModel.document.layers[2].style.shadowDistance == 12)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleShadowNoiseAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowNoise = 0.15
        second.style.shadowNoise = 0.8
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
        #expect(viewModel.document.layers[0].style.shadowNoise == 0.6)
        #expect(viewModel.document.layers[1].style.shadowNoise == 0.6)
        #expect(viewModel.document.layers[2].style.shadowNoise == 0.4)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleShadowSpreadAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowSpread = 2
        second.style.shadowSpread = 16
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
        #expect(viewModel.document.layers[0].style.shadowSpread == 10)
        #expect(viewModel.document.layers[1].style.shadowSpread == 10)
        #expect(viewModel.document.layers[2].style.shadowSpread == 6)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleShadowBlurAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.shadowBlur = 4
        second.style.shadowBlur = 18
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
        #expect(viewModel.document.layers[0].style.shadowBlur == 12)
        #expect(viewModel.document.layers[1].style.shadowBlur == 12)
        #expect(viewModel.document.layers[2].style.shadowBlur == 9)
        #expect(viewModel.document.layers[0].style.shadowEnabled)
        #expect(viewModel.document.layers[1].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
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

    @Test func registrySetsLayerStyleColorOverlayOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.colorOverlayOpacity = 0.25
        second.style.colorOverlayOpacity = 0.75
        locked.style.colorOverlayOpacity = 0.4
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
        #expect(viewModel.document.layers[0].style.colorOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.colorOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.colorOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.colorOverlayEnabled)
        #expect(viewModel.document.layers[1].style.colorOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleGradientOverlayOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayOpacity = 0.25
        second.style.gradientOverlayOpacity = 0.75
        locked.style.gradientOverlayOpacity = 0.4
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
        #expect(viewModel.document.layers[0].style.gradientOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.gradientOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.gradientOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleGradientOverlayScaleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayScale = 0.5
        second.style.gradientOverlayScale = 2
        locked.style.gradientOverlayScale = 1
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
        #expect(viewModel.document.layers[0].style.gradientOverlayScale == 1.5)
        #expect(viewModel.document.layers[1].style.gradientOverlayScale == 1.5)
        #expect(viewModel.document.layers[2].style.gradientOverlayScale == 1)
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleGradientOverlayAngleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.gradientOverlayAngle = -45
        second.style.gradientOverlayAngle = 90
        locked.style.gradientOverlayAngle = 30
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
                "value": .number(120)
            ]
        ))

        #expect(result.ok)
        #expect(viewModel.document.layers[0].style.gradientOverlayAngle == 120)
        #expect(viewModel.document.layers[1].style.gradientOverlayAngle == 120)
        #expect(viewModel.document.layers[2].style.gradientOverlayAngle == 30)
        #expect(viewModel.document.layers[0].style.gradientOverlayEnabled)
        #expect(viewModel.document.layers[1].style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleGradientOverlayStyleWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayStyle == .diamond)
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func registrySetsLayerStylePatternOverlayKindWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.document.selectedLayer?.style.patternOverlayKind == .diagonalStripes)
        #expect(viewModel.document.selectedLayer?.style.patternOverlayEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func registrySetsLayerStylePatternOverlayScaleAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.patternOverlayScale = 8
        second.style.patternOverlayScale = 24
        locked.style.patternOverlayScale = 12
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
        #expect(viewModel.document.layers[0].style.patternOverlayScale == 32)
        #expect(viewModel.document.layers[1].style.patternOverlayScale == 32)
        #expect(viewModel.document.layers[2].style.patternOverlayScale == 12)
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[1].style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStylePatternOverlayOpacityAcrossEditableSelection() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.patternOverlayOpacity = 0.25
        second.style.patternOverlayOpacity = 0.75
        locked.style.patternOverlayOpacity = 0.4
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
        #expect(viewModel.document.layers[0].style.patternOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[1].style.patternOverlayOpacity == 0.6)
        #expect(viewModel.document.layers[2].style.patternOverlayOpacity == 0.4)
        #expect(viewModel.document.layers[0].style.patternOverlayEnabled)
        #expect(viewModel.document.layers[1].style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])
    }

    @Test func registrySetsLayerStyleShadowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.document.selectedLayer?.style.shadowContour == .cone)
        #expect(viewModel.document.selectedLayer?.style.shadowEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func registrySetsLayerStyleInnerShadowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.document.selectedLayer?.style.innerShadowContour == .ring)
        #expect(viewModel.document.selectedLayer?.style.innerShadowEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func registrySetsLayerStyleOuterGlowContourWithAdvertisedEnum() throws {
        let viewModel = makeViewModel()
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
        #expect(viewModel.document.selectedLayer?.style.outerGlowContour == .soft)
        #expect(viewModel.document.selectedLayer?.style.outerGlowEnabled == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
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

        let targetLayerID = try #require(viewModel.document.layers.first { $0.id != sourceLayerID }?.id)
        viewModel.document.selectedLayerID = targetLayerID
        viewModel.document.selectedLayerIDs = [targetLayerID]
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
