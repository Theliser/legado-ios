import AVFoundation
import Foundation
@testable import Legado
import SwiftData
import Testing

@Suite("TTS and WebDAV Cloud Sync Suite")
struct TTSAndWebDAVSyncTests {

    // MARK: - 文本净化与规则测试

    @Test("Test Purify Content Removes Ads and Page Turn Prompts")
    func purifyContentRemovesAds() {
        let purifyUseCase = PurifyContentUseCase()
        let rawContent = """
        　　夜幕降临，风吹过荒野。
        本章未完，请点击下一页继续阅读！
        笔趣阁最快更新！关注网址 https://ad.example.com/promo
        　　卢米安握紧了手中的吊坠。
        """

        let cleaned = purifyUseCase.execute(content: rawContent)
        #expect(!cleaned.contains("本章未完"))
        #expect(!cleaned.contains("https://ad.example.com"))
        #expect(!cleaned.contains("最快更新"))
        #expect(cleaned.contains("夜幕降临"))
        #expect(cleaned.contains("卢米安握紧"))
    }

    @Test("Test Custom User Regex Replacement Rule")
    func customUserRegexRule() {
        let purifyUseCase = PurifyContentUseCase()
        let rawContent = "错别字【乌贼】与特定标记【VIP】"
        let customRule = ReplaceRule(
            name: "标记替换",
            pattern: "【VIP】",
            replacement: "[精品]")

        let cleaned = purifyUseCase.execute(
            content: rawContent,
            customRules: [customRule])

        #expect(cleaned.contains("[精品]"))
        #expect(!cleaned.contains("【VIP】"))
    }

    // MARK: - 朗读断句与状态机测试

    @Test("Test TTS Sentence Splitting and Normalization")
    @MainActor
    func ttsSentenceSplitting() {
        let player = TTSPlayer.shared
        player.stop()

        let sampleText = """
        夜幕降临！荒野的风在呼啸？
        卢米安低语：“开始吧。”
        命运的齿轮转动了。
        """

        player.startReading(
            content: sampleText,
            bookTitle: "宿命之环",
            chapterTitle: "第一章",
            author: "爱潜水的乌贼")

        #expect(player.totalSentences >= 3)
        #expect(player.state == .playing)
        #expect(player.currentSentenceIndex == 0)

        // 测试暂停与恢复
        player.pause()
        #expect(player.state == .paused)

        player.resume()
        #expect(player.state == .playing)

        player.stop()
        #expect(player.state == .idle)
    }

    @Test("Test TTS Rate and Sleep Timer Adjustments")
    @MainActor
    func ttsRateAndTimer() {
        let player = TTSPlayer.shared
        player.speechRate = 0.55
        player.speechPitch = 1.2

        #expect(player.speechRate == 0.55)
        #expect(player.speechPitch == 1.2)

        player.setSleepTimer(minutes: 15)
        #expect(player.timerRemainingSeconds == 15 * 60)

        player.clearSleepTimer()
        #expect(player.timerRemainingSeconds == nil)
    }

    // MARK: - WebDAV 序列化与备份恢复测试

    @Test("Test WebDAV Config Validation")
    func webDAVConfigValidation() {
        var config = WebDAVConfig()
        #expect(!config.isValid)

        config.serverUrl = "https://dav.jianguoyun.com/dav/"
        config.username = "test@example.com"
        config.password = "app-password"
        #expect(config.isValid)
    }

    @Test("Test WebDAV Backup Bundle Serialization Roundtrip")
    func webDAVBundleSerialization() throws {
        let sampleBook = Book(
            bookUrl: "https://example.com/b1",
            tocUrl: "https://example.com/toc1",
            origin: "https://example.com",
            originName: "测试源",
            name: "诡秘之主",
            author: "乌贼")

        let sampleSource = BookSource(
            bookSourceUrl: "https://example.com",
            bookSourceName: "测试源",
            bookSourceType: 0)

        let bundle = WebDAVBackupBundle(
            version: 1,
            backupTime: Date(),
            appVersion: "1.0.0",
            books: [sampleBook],
            sources: [sampleSource],
            replaceRules: PurifyContentUseCase.defaultRules)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(WebDAVBackupBundle.self, from: data)

        #expect(restored.version == 1)
        #expect(restored.books.count == 1)
        #expect(restored.books.first?.name == "诡秘之主")
        #expect(restored.sources.count == 1)
        #expect(restored.sources.first?.bookSourceName == "测试源")
        #expect(!restored.replaceRules.isEmpty)
    }
}
