//
//  veilpicUITests.swift
//  veilpicUITests
//
//  Created by rocky on 2026/5/19.
//

import XCTest

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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
