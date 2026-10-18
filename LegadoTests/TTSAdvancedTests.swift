import AVFoundation
import Foundation
@testable import Legado
import SwiftUI
import Testing

@Suite("TTS Advanced Features and Sleep Timer Suite")
struct TTSAdvancedTests {

    // MARK: - 定时模式与描述测试

    @Test("Test TTSTimerMode Descriptions and Active States")
    func timerModeDescriptions() {
        let noneMode = TTSTimerMode.none
        #expect(!noneMode.isActive)
        #expect(noneMode.shortDescription == nil)
        #expect(noneMode.detailDescription == "未设置定时")

        let minuteMode = TTSTimerMode.minutes(totalMinutes: 30, remainingSeconds: 1795, finishChapterFirst: false)
        #expect(minuteMode.isActive)
        #expect(minuteMode.shortDescription == "29:55")
        #expect(minuteMode.detailDescription.contains("定时 30 分钟"))

        let finishChapterMode = TTSTimerMode.minutes(totalMinutes: 15, remainingSeconds: 0, finishChapterFirst: true)
        #expect(!finishChapterMode.isActive)
        #expect(finishChapterMode.shortDescription == "读完停")
        #expect(finishChapterMode.detailDescription.contains("读完本章后停止"))

        let chapterMode = TTSTimerMode.chapters(totalChapters: 3, remainingChapters: 2)
        #expect(chapterMode.isActive)
        #expect(chapterMode.shortDescription == "剩2章")
        #expect(chapterMode.detailDescription == "定时 3 章 (剩余 2 章)")
    }

    // MARK: - 声音与全局设置持久化测试

    @Test("Test TTSVoice Entity and Language Properties")
    func ttsVoiceProperties() {
        let cnVoice = TTSVoice(id: "com.apple.voice.tingting", name: "Tingting", language: "zh-CN", qualityDescription: "增强")
        #expect(cnVoice.isChinese)
        #expect(!cnVoice.languageDisplayName.isEmpty)

        let enVoice = TTSVoice(id: "com.apple.voice.samantha", name: "Samantha", language: "en-US", qualityDescription: "标准")
        #expect(!enVoice.isChinese)
    }

    @Test("Test TTSConfig Bounds Clamping and Serialization")
    func ttsConfigSerialization() throws {
        // 验证上下界限制
        let clampedLow = TTSConfig(speechRateMultiplier: 0.1, speechPitch: 0.1)
        #expect(clampedLow.speechRateMultiplier == 0.5)
        #expect(clampedLow.speechPitch == 0.5)

        let clampedHigh = TTSConfig(speechRateMultiplier: 3.5, speechPitch: 2.5)
        #expect(clampedHigh.speechRateMultiplier == 2.0)
        #expect(clampedHigh.speechPitch == 1.5)

        // 验证 JSON 序列化与反序列化
        let original = TTSConfig(
            speechRateMultiplier: 1.25,
            speechPitch: 1.1,
            voiceIdentifier: "test.voice.id",
            finishCurrentChapterAfterTimer: true,
            isFadeOutEnabled: true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let restored = try JSONDecoder().decode(TTSConfig.self, from: data)

        #expect(restored.speechRateMultiplier == 1.25)
        #expect(restored.speechPitch == 1.1)
        #expect(restored.voiceIdentifier == "test.voice.id")
        #expect(restored.finishCurrentChapterAfterTimer)
        #expect(restored.isFadeOutEnabled)
    }

    // MARK: - TTSPlayer 睡眠定时器与播放调度测试

    @Test("Test TTSPlayer Minute Sleep Timer Setup and Cancellation")
    @MainActor
    func playerMinuteSleepTimer() {
        let player = TTSPlayer.shared
        player.clearTimer()
        #expect(player.timerMode == .none)

        player.setMinuteTimer(minutes: 20, finishChapterFirst: false)
        if case let .minutes(total, remaining, finishFirst) = player.timerMode {
            #expect(total == 20)
            #expect(remaining == 1200)
            #expect(!finishFirst)
        } else {
            Issue.record("Expected .minutes timer mode")
        }

        player.clearTimer()
        #expect(player.timerMode == .none)
    }

    @Test("Test TTSPlayer Chapter Sleep Timer and Decrement")
    @MainActor
    func playerChapterSleepTimer() {
        let player = TTSPlayer.shared
        player.clearTimer()

        player.setChapterTimer(chapters: 5)
        if case let .chapters(total, remaining) = player.timerMode {
            #expect(total == 5)
            #expect(remaining == 5)
        } else {
            Issue.record("Expected .chapters timer mode")
        }

        // 提供下一章以模拟跨章节连续听书
        player.onRequestNextChapter = {
            (title: "第二章", content: "新的一章开始了。")
        }

        // 模拟一章读完，章节倒计时递减
        player.advanceToNextChapterOrStop()
        if case let .chapters(total, remaining) = player.timerMode {
            #expect(total == 5)
            #expect(remaining == 4)
        } else {
            Issue.record("Expected .chapters timer mode decremented")
        }

        player.onRequestNextChapter = nil
        player.clearTimer()
    }

    @Test("Test TTSPlayer Sentence Jumping and Callback Dispatch")
    @MainActor
    func playerSentenceJumping() {
        let player = TTSPlayer.shared
        let content = """
        第一句：星光璀璨。
        第二句：夜风吹拂着山岗。
        第三句：冒险从这里启程。
        """

        var notifiedSentence = ""
        var notifiedIndex = -1
        player.onSentenceChanged = { idx, str in
            notifiedIndex = idx
            notifiedSentence = str
        }

        player.startReading(
            content: content,
            bookTitle: "测试书籍",
            chapterTitle: "第一章",
            author: "测试作者",
            startIndex: 0)

        #expect(player.state == .playing)
        #expect(player.totalSentences == 3)
        #expect(player.currentSentenceIndex == 0)
        #expect(notifiedIndex == 0)

        // 跳转至第三句 (index 2)
        player.jumpToSentence(at: 2)
        #expect(player.currentSentenceIndex == 2)
        #expect(notifiedIndex == 2)
        #expect(notifiedSentence.contains("冒险从这里启程"))

        player.stop()
        #expect(player.state == .idle)
    }

    // MARK: - 阅读界面高亮与断句逻辑

    @Test("Test Reader Page Sentence Highlight Matching")
    func pageSentenceHighlightMatching() {
        let sampleContent = "深红的月光从云层缝隙洒落。卢米安站立在石阶前。他知道时间不多了。"
        let targetSentence = "卢米安站立在石阶前。"

        var attr = AttributedString(sampleContent)
        let foundRange = attr.range(of: targetSentence)
        #expect(foundRange != nil)

        if let range = foundRange {
            attr[range].foregroundColor = .accentColor
            #expect(attr[range].foregroundColor == .accentColor)
        }
    }
}
