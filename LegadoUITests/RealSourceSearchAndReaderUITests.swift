import UIKit
import XCTest

/// 真实书源全链路自动化走查与截图测试套件
/// 覆盖：书架/搜索 -> 真实网络聚合搜索 -> 书籍详情解析 -> 沉浸式正文阅读排版 -> 液态玻璃 HUD -> 真实章节目录
final class RealSourceSearchAndReaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testRealBookSourceCompleteFlow() {

        // MARK: - 步骤 1: 切换到底栏【搜索】标签页

        let searchTab = app.tabBars.buttons["搜索"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 8), "底栏应展示【搜索】标签")
        searchTab.tap()

        // 验证进入搜索控制台
        let searchBar = app.searchFields.firstMatch
        XCTAssertTrue(searchBar.waitForExistence(timeout: 5), "应出现官方系统级搜索框")
        saveScreenshot(name: "real_01_search_dashboard")

        // MARK: - 步骤 2: 输入真实关键词【剑神重生】

        searchBar.tap()
        searchBar.typeText("剑神重生\n")
        Thread.sleep(forTimeInterval: 0.5)
        saveScreenshot(name: "real_02_search_input")

        // MARK: - 步骤 3: 等待真实书源（酷我小说 API）实时聚合搜索结果

        let bookTitleText = app.staticTexts["剑神重生"]
        XCTAssertTrue(
            bookTitleText.waitForExistence(timeout: 12),
            "真实网络搜索应在 12 秒内返回《剑神重生》书籍卡片")

        // 验证作者与标签渲染
        let authorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '天雷猪'")).firstMatch
        XCTAssertTrue(authorText.waitForExistence(timeout: 5), "书籍卡片应正确渲染作者【天雷猪】")
        saveScreenshot(name: "real_03_search_results")

        // MARK: - 步骤 4: 点击书籍卡片进入【书籍详情页】

        bookTitleText.tap()

        // 验证成功进入 BookDetailView
        let startReadingBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '开始阅读' OR label CONTAINS '继续阅读'")).firstMatch
        XCTAssertTrue(startReadingBtn.waitForExistence(timeout: 8), "书籍详情页应展示【开始阅读】高光主按钮")

        // 留出时间让详情与目录异步解析完毕
        Thread.sleep(forTimeInterval: 2.0)
        saveScreenshot(name: "real_04_book_detail")

        // MARK: - 步骤 5: 点击【开始阅读】进入沉浸式阅读器

        startReadingBtn.tap()

        // 等待阅读器全屏呈现并加载正文
        Thread.sleep(forTimeInterval: 3.0)
        saveScreenshot(name: "real_05_reader_content")

        // MARK: - 步骤 6: 点击屏幕中央唤出【液态玻璃 HUD 控制面板】

        let window = app.windows.firstMatch
        let centerCoord = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        centerCoord.tap()

        // 验证 HUD 顶部标题与底部控制面板显现
        let tocButton = app.buttons["目录"]
        XCTAssertTrue(tocButton.waitForExistence(timeout: 4), "唤起 HUD 后底部应展示【目录】快捷操作按钮")
        Thread.sleep(forTimeInterval: 0.5)
        saveScreenshot(name: "real_06_reader_hud")

        // MARK: - 步骤 7: 点击【目录】唤起真实章节目录抽屉

        tocButton.tap()

        // 验证目录抽屉展现
        let firstChapterText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '第一章' OR label CONTAINS '海天'")).firstMatch
        XCTAssertTrue(firstChapterText.waitForExistence(timeout: 6), "目录抽屉中应成功拉取真实章节列表")
        Thread.sleep(forTimeInterval: 1.0)
        saveScreenshot(name: "real_07_reader_toc")
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
