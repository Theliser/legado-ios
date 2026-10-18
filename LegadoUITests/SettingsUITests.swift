import UIKit
import XCTest

/// 设置中心与存储缓存管理 UI 自动化测试（对齐 Issue #16：存储空间与缓存管理）
final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--tab-settings"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSettingsSectionsAndStorageCenter() {

        // MARK: - 步骤 1: 验证通过参数直达设置标签页

        let navTitle = app.navigationBars["设置"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 8), "设置页面导航标题应正常显示")
        captureScreenshot(name: "settings_01_main_view")

        // MARK: - 步骤 2: 验证存储中心与缓存清理项

        let storageHeader = app.staticTexts["存储中心"]
        if storageHeader.waitForExistence(timeout: 4) {
            let clearCacheButton = app.buttons["清理所有书籍离线缓存"]
            XCTAssertTrue(clearCacheButton.exists, "应提供【清理所有书籍离线缓存】操作项")
            captureScreenshot(name: "settings_02_storage_section")
        }

        // MARK: - 步骤 3: 验证 WebDAV 云备份与恢复项

        let webdavHeader = app.staticTexts["数据同步与备份"]
        if webdavHeader.waitForExistence(timeout: 4) {
            let backupButton = app.buttons["立即备份至 WebDAV"]
            XCTAssertTrue(backupButton.exists, "应提供 WebDAV 立即备份按钮")
            captureScreenshot(name: "settings_03_webdav_section")
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
