import UIKit
import XCTest

/// 阅读器核心与高级特性 UI 自动化测试（对齐 Issue #14、#16、#17：目录/书签、全文搜索、一键换源、离线缓存与听书面板）
final class ReaderAndFeaturesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--open-reader-hud"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testReaderHUDTocBookmarksSearchAndTTS() {

        // MARK: - 步骤 1: 验证阅读器 HUD 成功展现

        let bookTitle = app.staticTexts["宿命之环"]
        XCTAssertTrue(bookTitle.waitForExistence(timeout: 8), "阅读器 HUD 顶部应展示书名【宿命之环】")
        captureScreenshot(name: "reader_01_hud_active")

        // MARK: - 步骤 2: 打开目录抽屉并切换至书签栏目 (Issue #14)

        let tocButton = app.buttons["目录"]
        if tocButton.waitForExistence(timeout: 4) {
            tocButton.tap()

            let bookmarkTab = app.buttons["书签"]
            XCTAssertTrue(bookmarkTab.waitForExistence(timeout: 5), "目录与书签液态面板应成功弹出")
            captureScreenshot(name: "reader_02_toc_sheet")

            // 切换至书签 Tab
            bookmarkTab.tap()
            captureScreenshot(name: "reader_03_bookmarks_tab")

            let closeTocButton = app.buttons.matching(identifier: "完成").firstMatch
            if closeTocButton.waitForExistence(timeout: 3) {
                closeTocButton.tap()
                _ = bookmarkTab.waitForNonExistence(timeout: 3)
            }
        }

        // MARK: - 步骤 3: 打开正文全文搜索面板 (Issue #14)

        let searchButton = app.buttons["搜索"]
        if searchButton.waitForExistence(timeout: 4) {
            tapElementSafely(searchButton)

            let searchField = app.textFields["搜索本书正文内容..."]
            if searchField.waitForExistence(timeout: 4) {
                captureScreenshot(name: "reader_04_search_content_sheet")
                searchField.tap()
                searchField.typeText("命运")
                captureScreenshot(name: "reader_05_search_content_typed")
            }

            let doneSearchButton = app.buttons.matching(identifier: "完成").firstMatch
            if doneSearchButton.waitForExistence(timeout: 3) {
                doneSearchButton.tap()
                _ = searchField.waitForNonExistence(timeout: 3)
            }
        }

        // MARK: - 步骤 4: 打开一键换源面板 (Issue #14)

        let changeSourceButton = app.buttons["换源"]
        if changeSourceButton.waitForExistence(timeout: 4) {
            tapElementSafely(changeSourceButton)

            let closeChangeSource = app.buttons.matching(identifier: "完成").firstMatch
            if closeChangeSource.waitForExistence(timeout: 4) {
                captureScreenshot(name: "reader_06_change_source_sheet")
                closeChangeSource.tap()
                _ = closeChangeSource.waitForNonExistence(timeout: 3)
            }
        }

        // MARK: - 步骤 5: 打开离线章节缓存面板 (Issue #16)

        let cacheTopButton = app.buttons["arrow.down.circle"]
        if cacheTopButton.waitForExistence(timeout: 4) {
            tapElementSafely(cacheTopButton)

            let closeCache = app.buttons.matching(identifier: "完成").firstMatch
            if closeCache.waitForExistence(timeout: 4) {
                captureScreenshot(name: "reader_07_book_cache_sheet")
                closeCache.tap()
                _ = closeCache.waitForNonExistence(timeout: 3)
            }
        }

        // MARK: - 步骤 6: 唤起听书控制 (Issue #17)

        let ttsButton = app.buttons["听书"]
        if ttsButton.waitForExistence(timeout: 4) {
            tapElementSafely(ttsButton)
            captureScreenshot(name: "reader_08_tts_floating_active")
        }
    }

    private func tapElementSafely(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func captureScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
