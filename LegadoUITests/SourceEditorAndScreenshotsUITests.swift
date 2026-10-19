import UIKit
import XCTest

/// 书源编辑器与多维视图 UI 自动化视觉走查与截图套件
/// 验证 iOS 18+ 原生液态玻璃界面、6 Tab 可视化规则编辑器、语法提示胶囊栏与 JSON 模式切换
final class SourceEditorAndScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSourceManagementAndEditorVisualFlow() {

        // MARK: - 步骤 1: 导航进入【书源】标签页

        let sourceTab = app.tabBars.buttons["书源"]
        XCTAssertTrue(sourceTab.waitForExistence(timeout: 8), "底栏应显示【书源】标签")
        sourceTab.tap()

        // 等待书源列表加载
        let biqugeCard = app.staticTexts["笔趣阁官方"]
        XCTAssertTrue(biqugeCard.waitForExistence(timeout: 6), "应显示内置书源【笔趣阁官方】")
        saveScreenshot(name: "source_editor_01_sourcemanage_screen")

        // MARK: - 步骤 2: 点击书源卡片进入【书源编辑器】

        let cardButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '笔趣阁官方'")).firstMatch
        let cardTarget = cardButton.exists ? cardButton : biqugeCard
        cardTarget.tap()

        // 验证书源编辑器弹窗成功展示（通过左上角【取消】按钮判断）
        let cancelBtn = app.buttons["取消"]
        XCTAssertTrue(cancelBtn.waitForExistence(timeout: 5), "点击书源卡片后应成功弹出书源编辑器")

        // 验证语法胶囊栏在屏
        let jsonChip = app.staticTexts["@json:"].exists ? app.staticTexts["@json:"] : app.buttons["@json:"]
        XCTAssertTrue(jsonChip.waitForExistence(timeout: 3), "底部语法助手栏应渲染【@json:】语法胶囊")
        saveScreenshot(name: "source_editor_02_edit_base_tab")

        // MARK: - 步骤 3: 切换到【搜索】规则标签页

        let searchTab = app.staticTexts["搜索"].exists ? app.staticTexts["搜索"] : app.buttons["搜索"]
        if searchTab.waitForExistence(timeout: 3) {
            searchTab.tap()
            Thread.sleep(forTimeInterval: 0.5)
            saveScreenshot(name: "source_editor_03_edit_search_tab")
        }

        // MARK: - 步骤 4: 切换到【正文】规则标签页

        let contentTab = app.staticTexts["正文"].exists ? app.staticTexts["正文"] : app.buttons["正文"]
        if contentTab.waitForExistence(timeout: 3) {
            contentTab.tap()
            Thread.sleep(forTimeInterval: 0.5)
            saveScreenshot(name: "source_editor_04_edit_content_tab")
        }

        // MARK: - 步骤 5: 切换到【JSON 源码模式】

        let jsonToggleBtn = app.buttons["curlybraces"]
        if jsonToggleBtn.waitForExistence(timeout: 3) {
            jsonToggleBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
            saveScreenshot(name: "source_editor_05_raw_json_mode")

            // 切回表单模式
            let formToggleBtn = app.buttons["list.bullet.rectangle"]
            if formToggleBtn.waitForExistence(timeout: 3) {
                formToggleBtn.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // MARK: - 步骤 6: 从编辑器内直接点击【调试】图标

        let debugBtn = app.buttons["ladybug"]
        if debugBtn.waitForExistence(timeout: 3) {
            debugBtn.tap()

            let debugTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '调试:'")).firstMatch
            if debugTitle.waitForExistence(timeout: 4) {
                // 点击快捷预设示例或开始调试
                let exampleChip = app.buttons.matching(NSPredicate(format: "label CONTAINS '宿命'")).firstMatch
                if exampleChip.waitForExistence(timeout: 2) {
                    exampleChip.tap()
                }

                let startDebugBtn = app.buttons["开始"]
                if startDebugBtn.waitForExistence(timeout: 2) {
                    startDebugBtn.tap()
                    Thread.sleep(forTimeInterval: 1.5)
                }
                saveScreenshot(name: "source_editor_06_live_debugger")

                // 关闭调试抽屉
                let doneBtn = app.buttons["完成"]
                if doneBtn.waitForExistence(timeout: 3) {
                    doneBtn.tap()
                }
            }
        }

        // MARK: - 步骤 7: 取消关闭编辑器回到书源列表

        let dismissBtn = app.buttons["取消"]
        if dismissBtn.exists {
            dismissBtn.tap()
        }

        // MARK: - 步骤 8: 唤起右上角新建/导入菜单

        let manageNav = app.navigationBars["书源"]
        let plusBtn = manageNav.buttons.element(boundBy: max(0, manageNav.buttons.count - 1))
        if plusBtn.waitForExistence(timeout: 3) {
            plusBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
            saveScreenshot(name: "source_editor_07_plus_menu")
        }
    }

    private func saveScreenshot(name: String) {
        let screenshot = app.screenshot()
        let data = screenshot.pngRepresentation

        let tmpUrl = URL(fileURLWithPath: "/tmp/\(name).png")
        try? data.write(to: tmpUrl)

        let brainDir = URL(fileURLWithPath: "/Users/theliser/.gemini/antigravity/brain/c41a6137-b637-40ce-8e14-9ad2fbe03bc4")
        try? data.write(to: brainDir.appendingPathComponent("\(name).png"))

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
