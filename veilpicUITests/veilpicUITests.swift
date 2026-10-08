//
//  veilpicUITests.swift
//  veilpicUITests
//
//  Created by rocky on 2026/5/19.
//

import XCTest
import AppKit

final class veilpicUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testDraggingButtonFromLibraryCreatesEditableLayerGroup() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let componentsTab = app.buttons["组件库"]
        XCTAssertTrue(componentsTab.waitForExistence(timeout: 5))
        componentsTab.tap()

        let buttonComponent = app.buttons.matching(identifier: "xomo-component-library-item-button").firstMatch
        let canvas = app.descendants(matching: .any)
            .matching(identifier: "image-editor-canvas")
            .firstMatch
        XCTAssertTrue(buttonComponent.waitForExistence(timeout: 5))
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        buttonComponent.press(forDuration: 0.4, thenDragTo: canvas)

        let insertedStatus = app.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@", "已插入组件：按钮"))
            .firstMatch
        XCTAssertTrue(insertedStatus.waitForExistence(timeout: 5))
    }

    @MainActor
    func testToolButtonsRemainClickableAfterComponentLibraryRoundTrip() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let componentsTab = app.buttons["组件库"]
        let toolsTab = app.buttons["工具"]
        XCTAssertTrue(componentsTab.waitForExistence(timeout: 5))
        componentsTab.tap()
        XCTAssertTrue(toolsTab.waitForExistence(timeout: 5))
        toolsTab.tap()

        let brush = app.buttons.matching(identifier: "image-editor-tool-brush").firstMatch
        let eraser = app.buttons.matching(identifier: "image-editor-tool-eraser").firstMatch
        XCTAssertTrue(brush.waitForExistence(timeout: 5))
        XCTAssertTrue(eraser.waitForExistence(timeout: 5))

        brush.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertEqual(brush.value as? String, "selected")
        eraser.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).click()
        XCTAssertEqual(eraser.value as? String, "selected")
    }

    @MainActor
    func testComponentLibraryHoverAndSelectionRestoreSystemArrow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let toolsTab = app.buttons["工具"]
        let componentsTab = app.buttons["组件库"]
        let brush = app.buttons.matching(identifier: "image-editor-tool-brush").firstMatch
        let canvas = app.descendants(matching: .any)
            .matching(identifier: "image-editor-canvas")
            .firstMatch
        XCTAssertTrue(toolsTab.waitForExistence(timeout: 5))
        XCTAssertTrue(brush.waitForExistence(timeout: 5))
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        toolsTab.tap()
        brush.click()
        canvas.hover()
        XCTAssertFalse(systemCursorMatches(NSCursor.arrow), "Brush hover should use its semantic brush cursor")

        componentsTab.tap()
        let component = app.buttons.matching(identifier: "xomo-component-library-item-button").firstMatch
        XCTAssertTrue(component.waitForExistence(timeout: 5))
        component.hover()
        XCTAssertTrue(systemCursorMatches(NSCursor.arrow), "Component library hover should restore the system arrow")

        component.click()
        XCTAssertTrue(systemCursorMatches(NSCursor.arrow), "Selecting a library component should retain the system arrow")

        toolsTab.tap()
        canvas.hover()
        XCTAssertFalse(systemCursorMatches(NSCursor.arrow), "Returning to the canvas should restore the selected brush cursor")
    }

    private func systemCursorMatches(_ expected: NSCursor) -> Bool {
        guard let current = NSCursor.currentSystem else { return false }
        return current === expected
            || current.image.tiffRepresentation == expected.image.tiffRepresentation
    }

    @MainActor
    func testEveryToolButtonRemainsClickableAfterComponentLibraryRoundTrip() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let componentsTab = app.buttons["组件库"]
        let toolsTab = app.buttons["工具"]
        XCTAssertTrue(componentsTab.waitForExistence(timeout: 5))
        componentsTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(toolsTab.waitForExistence(timeout: 5))
        toolsTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

        let toolIDs = [
            "move", "marquee", "lasso", "magicWand", "quickSelection", "crop",
            "brush", "eraser", "cloneStamp", "dodge", "burn", "sponge",
            "blur", "sharpen", "smudge", "healingBrush", "patchTool", "redEye",
            "paintBucket", "gradient", "eyedropper", "colorSampler", "text",
            "rectangle", "ellipse", "pen", "pathSelection", "directSelection",
            "hand", "zoom"
        ]
        let toolScrollView = app.scrollViews
            .matching(identifier: "xomo-left-sidebar")
            .firstMatch

        for toolID in toolIDs {
            if toolID == "pathSelection" {
                XCTAssertTrue(toolScrollView.waitForExistence(timeout: 5))
                toolScrollView.swipeUp()
            }
            let button = app.buttons
                .matching(identifier: "image-editor-tool-\(toolID)")
                .firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tool \(toolID)")
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            XCTAssertEqual(button.value as? String, "selected", "Tool \(toolID) did not activate")
        }
    }

    @MainActor
    func testToolButtonsRemainClickableAfterDraggingComponentToCanvas() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let componentsTab = app.buttons["组件库"]
        let toolsTab = app.buttons["工具"]
        XCTAssertTrue(componentsTab.waitForExistence(timeout: 5))
        componentsTab.tap()

        let buttonComponent = app.buttons
            .matching(identifier: "xomo-component-library-item-button")
            .firstMatch
        let canvas = app.descendants(matching: .any)
            .matching(identifier: "image-editor-canvas")
            .firstMatch
        XCTAssertTrue(buttonComponent.waitForExistence(timeout: 5))
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        buttonComponent.press(forDuration: 0.4, thenDragTo: canvas)

        let insertedStatus = app.staticTexts
            .matching(NSPredicate(format: "value CONTAINS %@", "已插入组件：按钮"))
            .firstMatch
        XCTAssertTrue(insertedStatus.waitForExistence(timeout: 5))

        XCTAssertTrue(toolsTab.waitForExistence(timeout: 5))
        toolsTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

        let brush = app.buttons.matching(identifier: "image-editor-tool-brush").firstMatch
        let eraser = app.buttons.matching(identifier: "image-editor-tool-eraser").firstMatch
        XCTAssertTrue(brush.waitForExistence(timeout: 5))
        XCTAssertTrue(eraser.waitForExistence(timeout: 5))
        brush.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertEqual(brush.value as? String, "selected")
        eraser.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertEqual(eraser.value as? String, "selected")
    }

    @MainActor
    func testLayerStylePresetManagerSearchesAndFiltersRealInterface() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-XomoUITestPresetManager", "YES"
        ]
        app.launch()

        let search = app.textFields["image-editor-layer-style-preset-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.click()
        search.typeText("neon")
        XCTAssertTrue(app.staticTexts["Neon Glow"].waitForExistence(timeout: 5))

        let scope = app.descendants(matching: .any)
            .matching(identifier: "image-editor-layer-style-preset-scope")
            .firstMatch
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        scope.radioButtons["Custom"].click()
        XCTAssertTrue(app.staticTexts["No matching style presets"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPreviewAndExportButtonsKeepEditorAliveAndPresentCorrectPanels() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let canvas = app.descendants(matching: .any)
            .matching(identifier: "image-editor-canvas")
            .firstMatch
        let previewButton = app.buttons["image-editor-action-preview"]
        let exportButton = app.buttons["image-editor-action-export"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 8))
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))

        previewButton.click()
        let previewPanel = app.descendants(matching: .any)
            .matching(identifier: "image-editor-preview-panel")
            .firstMatch
        XCTAssertTrue(previewPanel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(canvas.exists, "预览打开后主编辑画布必须继续存在")
        app.buttons["image-editor-preview-close"].click()
        XCTAssertTrue(previewPanel.waitForNonExistence(timeout: 5))

        exportButton.click()
        let exportPanel = app.descendants(matching: .any)
            .matching(identifier: "image-editor-export-panel")
            .firstMatch
        XCTAssertTrue(exportPanel.waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(canvas.exists, "导出面板打开后主编辑画布必须继续存在")
        app.buttons["image-editor-export-close"].click()
        XCTAssertTrue(exportPanel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(exportButton.isHittable, "关闭导出面板后编辑器必须仍可操作")
    }

    @MainActor
    func testDeleteKeyRemovesSelectedEditableLayerAndUndoRestoresIt() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let editableLayer = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "编辑图层"))
            .firstMatch
        XCTAssertTrue(editableLayer.waitForExistence(timeout: 8))
        editableLayer.click()

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            editableLayer.waitForNonExistence(timeout: 5),
            "Delete 应删除当前选中的可编辑图片图层"
        )

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(
            editableLayer.waitForExistence(timeout: 5),
            "撤销应恢复刚被 Delete 删除的图片图层"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
