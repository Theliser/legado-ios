import UIKit
import XCTest

/// 书源全流程 UI 自动化测试（基于 Apple 原生 XCUITest，对业务代码 0 侵入）
/// 严格遵循纯黑盒模拟器交互：
/// 1. 模拟器冷启并进入书源列表（初始状态，仅内置演示源）；
/// 2. 点击右上角【+】弹出导入面板；
/// 3. 从剪贴板粘贴真实书源 JSON 并确认导入；
/// 4. 验证新增书源实时上屏，点击进入【调试控制台】运行多阶段流式抓取；
/// 5. 调试完成后退出控制台，长按书源卡片唤起上下文菜单执行【删除书源】；
/// 6. 验证书源已被彻底移除，恢复初始纯净状态；
/// 全程高分辨率自动截图存盘。
final class SourceDebuggerUITests: XCTestCase {
    private var app: XCUIApplication!

    private let kuwoSourceJson = """
    {
      "bookSourceName": "酷我小说",
      "bookSourceUrl": "http://appi.kuwo.cn",
      "bookSourceType": 0,
      "bookSourceGroup": "API",
      "header": "{\\"User-Agent\\": \\"Dalvik/2.1.0 (Linux; U; Android 8.0.0; LND-AL40)\\"}",
      "searchUrl": "/novels/api/book/search?keyword={{key}}&pi={{page}}&ps=20",
      "weight": 80,
      "enabled": true,
      "ruleSearch": {
        "checkKeyWord": "修仙",
        "bookList": "$.data",
        "name": "$.title",
        "author": "$.author_name",
        "kind": "{{$.category_name}},{{$.status}}",
        "wordCount": "$.all_words",
        "intro": "$.intro",
        "coverUrl": "$.cover_url",
        "bookUrl": "/novels/api/book/{{$.book_id}}"
      },
      "ruleBookInfo": {
        "bookInfoInit": "$.data",
        "name": "$.title",
        "author": "$.author_name",
        "kind": "{{$.category_name}},{{$.status}}",
        "wordCount": "$.all_words",
        "intro": "$.intro",
        "coverUrl": "$.cover_url",
        "tocUrl": "/novels/api/book/{{$.book_id}}/chapters?paging=0"
      },
      "ruleToc": {
        "chapterList": "$.data",
        "chapterName": "$.chapter_title",
        "chapterUrl": "/novels/api/book/{{$.book_id}}/chapters/{{$.chapter_id}}"
      },
      "ruleContent": {
        "content": "$.data.content"
      }
    }
    """

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 自动化操控模拟器全流程：添加书源 -> 跑调试测试 -> 删除书源
    func testAddDebugAndDeleteSourceFlow() {

        // MARK: - 步骤 1: 进入“书源”原生导航标签页并记录初始状态

        let sourceTab = app.tabBars.buttons["书源"]
        XCTAssertTrue(sourceTab.waitForExistence(timeout: 8), "底栏书源标签页应正常显示")
        sourceTab.tap()

        // 验证初始状态：存在内置演示源，但尚无“酷我小说”
        let kuwoTitle = app.staticTexts["酷我小说"]
        let biqugeTitle = app.staticTexts["笔趣阁官方"]
        XCTAssertTrue(biqugeTitle.waitForExistence(timeout: 8), "书源列表中应包含内置笔趣阁官方")
        XCTAssertFalse(kuwoTitle.exists, "初始状态下不应存在酷我小说")

        // 截图 1: 初始书源列表
        captureScreenshot(name: "01_initial_source_list")

        // MARK: - 步骤 2: 点击右上角加号唤起“导入书源”面板

        let navBar = app.navigationBars["书源"]
        let plusButton = navBar.buttons["plus"].exists ? navBar.buttons["plus"] : navBar.buttons.firstMatch
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5), "右上角加号按钮应存在")
        plusButton.tap()

        let importSheetTitle = app.staticTexts["导入书源"]
        XCTAssertTrue(importSheetTitle.waitForExistence(timeout: 5), "导入书源液态面板应成功弹出")

        // 截图 2: 导入书源面板
        captureScreenshot(name: "02_import_sheet_open")

        // MARK: - 步骤 3: 粘贴书源 JSON 并确认导入

        UIPasteboard.general.string = kuwoSourceJson

        let pasteButton = app.buttons["从剪贴板粘贴"]
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 3), "应存在从剪贴板粘贴按钮")
        pasteButton.tap()

        // 处理 iOS 系统的跨应用剪贴板安全弹窗（由 SpringBoard 渲染）
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowPasteButton = springboard.buttons["允许粘贴"]
        let allowPasteEn = springboard.buttons["Allow Paste"]
        if allowPasteButton.waitForExistence(timeout: 2) {
            allowPasteButton.tap()
        } else if allowPasteEn.waitForExistence(timeout: 2) {
            allowPasteEn.tap()
        }

        // 点击确认导入
        let confirmButton = app.buttons["确认导入"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 4), "确认导入按钮应存在且处于就绪态")
        confirmButton.tap()

        // 等待导入面板自动关闭，并验证“酷我小说”在列表中实时渲染
        XCTAssertTrue(kuwoTitle.waitForExistence(timeout: 8), "导入后书源列表中应成功展示【酷我小说】")

        // 截图 3: 导入成功后的书源列表
        captureScreenshot(name: "03_source_imported_list")

        // MARK: - 步骤 4: 点击新导入的【酷我小说】唤起调试控制台并执行测试

        kuwoTitle.tap()

        let kuwoConsoleTitle = app.staticTexts["调试: 酷我小说"]
        XCTAssertTrue(kuwoConsoleTitle.waitForExistence(timeout: 5), "应成功弹出酷我小说调试面板")

        // 验证调试分段控制器切换至搜索
        let targetSegmented = app.segmentedControls.firstMatch
        if targetSegmented.buttons["搜索"].waitForExistence(timeout: 2) {
            targetSegmented.buttons["搜索"].tap()
        }

        // 点击开始调试
        let startButton = app.buttons["开始"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3), "开始调试按钮应可用")
        startButton.tap()

        // 监听在线多阶段流式抓取日志上屏
        let logPredicate = NSPredicate(format: "label CONTAINS '阶段' OR label CONTAINS '完成' OR label CONTAINS '耗时'")
        let logItem = app.staticTexts.matching(logPredicate).firstMatch
        XCTAssertTrue(logItem.waitForExistence(timeout: 10), "调试控制台应流式打印出阶段执行日志")

        // 截图 4: 酷我小说实时调试中与抓取日志
        captureScreenshot(name: "04_debugger_running_realtime_logs")

        // 关闭调试控制台
        app.buttons["完成"].tap()

        // MARK: - 步骤 5: 长按书源卡片唤起上下文菜单，执行【删除书源】

        XCTAssertTrue(kuwoTitle.waitForExistence(timeout: 5), "关闭调试后应回到书源列表")

        // 长按卡片 1.5 秒唤起 iOS 上下文菜单
        kuwoTitle.press(forDuration: 1.5)

        let deleteButton = app.buttons["删除书源"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 4), "上下文菜单中应出现【删除书源】按钮")

        // 截图 5: 长按上下文菜单
        captureScreenshot(name: "05_context_menu_delete")

        deleteButton.tap()

        // MARK: - 步骤 6: 验证书源已被彻底移除

        let kuwoDisappeared = kuwoTitle.waitForNonExistence(timeout: 5)
        XCTAssertTrue(kuwoDisappeared, "【酷我小说】书源应已从列表中彻底删除")

        // 笔趣阁官方依旧保留
        XCTAssertTrue(biqugeTitle.exists, "内置演示源应保持完好")

        // 截图 6: 删除后的纯净书源列表
        captureScreenshot(name: "06_source_deleted_clean_list")
    }

    private func captureScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
