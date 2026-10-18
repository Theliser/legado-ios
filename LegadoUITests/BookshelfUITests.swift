import UIKit
import XCTest

/// 书架全功能 UI 自动化测试（对齐 Issue #15：分组管理、视图切换、批量操作）
final class BookshelfUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testBookshelfLayoutGroupingAndBatchMode() {

        // MARK: - 步骤 1: 验证书架主视图加载

        let bookshelfTab = app.tabBars.buttons["书架"]
        XCTAssertTrue(bookshelfTab.waitForExistence(timeout: 8), "底栏应包含【书架】导航标签")
        bookshelfTab.tap()

        let navTitle = app.navigationBars["书架"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "书架导航标题应正常显示")
        captureScreenshot(name: "bookshelf_01_main_grid")

        // MARK: - 步骤 2: 切换宫格视图与列表视图

        let navBarButtons = navTitle.buttons
        let layoutButton = navBarButtons.element(boundBy: 0)
        if layoutButton.exists {
            layoutButton.tap()
            captureScreenshot(name: "bookshelf_02_switched_to_list")

            // 再次点击切回宫格
            layoutButton.tap()
            captureScreenshot(name: "bookshelf_03_switched_back_to_grid")
        }

        // MARK: - 步骤 3: 切换书架分类胶囊标签

        let inReadPill = app.buttons["在读"]
        if inReadPill.waitForExistence(timeout: 3) {
            inReadPill.tap()
            captureScreenshot(name: "bookshelf_04_filter_in_read")
        }

        let allPill = app.buttons["全部"]
        if allPill.waitForExistence(timeout: 3) {
            allPill.tap()
            captureScreenshot(name: "bookshelf_05_filter_all")
        }

        // MARK: - 步骤 4: 进入批量管理模式

        let batchManageButton = app.buttons["管理"]
        if batchManageButton.waitForExistence(timeout: 3) {
            batchManageButton.tap()

            let doneButton = app.buttons["完成"]
            XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "点击管理后应出现【完成】按钮")
            captureScreenshot(name: "bookshelf_06_batch_mode_active")

            let selectAllButton = app.buttons["全选"]
            if selectAllButton.exists {
                selectAllButton.tap()
                captureScreenshot(name: "bookshelf_07_batch_select_all")
            }

            doneButton.tap()
            captureScreenshot(name: "bookshelf_08_batch_mode_exited")
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
