import XCTest

/// 书源调试控制台 UI 自动化测试（基于 Apple 原生 XCUITest，对业务代码 0 侵入）
final class SourceDebuggerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// 自动化操控模拟器：测试【酷我小说】与【笔趣阁官方】两大书源的多阶段调试与实时流式日志
    func testSourceDebuggerWorkflow() {
        // 1. 切换至“书源”原生导航标签页
        let sourceTab = app.tabBars.buttons["书源"]
        XCTAssertTrue(sourceTab.waitForExistence(timeout: 8), "底栏书源标签页应正常显示")
        sourceTab.tap()

        // 2. 验证书源列表加载成功（包含内置种子书源）
        let kuwoTitle = app.staticTexts["酷我小说"]
        XCTAssertTrue(kuwoTitle.waitForExistence(timeout: 8), "书源列表中应包含酷我小说")

        let biqugeTitle = app.staticTexts["笔趣阁官方"]
        XCTAssertTrue(biqugeTitle.waitForExistence(timeout: 5), "书源列表中应包含笔趣阁官方")

        // 捕获书源列表界面
        captureScreenshot(name: "01_source_list_native")

        // 3. 点击【酷我小说】卡片，唤起液态玻璃调试控制台
        kuwoTitle.tap()

        let kuwoConsoleTitle = app.staticTexts["调试: 酷我小说"]
        XCTAssertTrue(kuwoConsoleTitle.waitForExistence(timeout: 5), "应成功弹出酷我小说调试面板")

        // 4. 验证五大调试阶段分段器并依次切换体验
        let targetSegmented = app.segmentedControls.firstMatch
        let targetButtons = ["发现", "详情", "目录", "正文", "搜索"]
        for target in targetButtons {
            let btn = targetSegmented.buttons[target]
            if btn.waitForExistence(timeout: 2) {
                btn.tap()
            }
        }

        // 切回搜索阶段并点击开始执行在线调试
        targetSegmented.buttons["搜索"].tap()
        let startButton = app.buttons["开始"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3), "开始调试按钮应可用")
        startButton.tap()

        // 5. 等待在线多阶段流式日志实时渲染
        let predicate = NSPredicate(format: "label CONTAINS '阶段' OR label CONTAINS '完成' OR label CONTAINS '耗时'")
        let logItem = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(logItem.waitForExistence(timeout: 10), "调试控制台应流式打印出阶段执行日志")

        // 捕获酷我小说调试运行状态
        captureScreenshot(name: "02_kuwo_debug_console")

        // 点击完成关闭弹窗
        app.buttons["完成"].tap()

        // 6. 操控测试第二个书源【笔趣阁官方】
        XCTAssertTrue(biqugeTitle.waitForExistence(timeout: 5))
        biqugeTitle.tap()

        let biqugeConsoleTitle = app.staticTexts["调试: 笔趣阁官方"]
        XCTAssertTrue(biqugeConsoleTitle.waitForExistence(timeout: 5), "应成功弹出笔趣阁官方调试面板")

        // 切换至“发现”调试目标
        let biqugeSegmented = app.segmentedControls.firstMatch
        biqugeSegmented.buttons["发现"].tap()

        // 点击预置示例胶囊
        let exampleChip = app.buttons.matching(NSPredicate(format: "label CONTAINS '发现'")).firstMatch
        if exampleChip.waitForExistence(timeout: 3) {
            exampleChip.tap()
        }

        // 启动发现规则调试
        app.buttons["开始"].tap()

        // 等待执行日志
        let biqugeLog = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '发现' OR label CONTAINS '阶段'")).firstMatch
        _ = biqugeLog.waitForExistence(timeout: 5)

        // 捕获笔趣阁调试界面
        captureScreenshot(name: "03_biquge_explore_debug")

        // 点击完成退出
        app.buttons["完成"].tap()
    }

    private func captureScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
