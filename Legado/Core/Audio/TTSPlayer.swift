import AVFoundation
import Foundation
import MediaPlayer

/// 朗读播放状态
public enum TTSPlaybackState: String, Sendable {
    case idle
    case playing
    case paused
}

/// 基于 AVSpeechSynthesizer 与 NowPlayingInfoCenter 的原生语音朗读中枢
@MainActor
public final class TTSPlayer: NSObject, ObservableObject {
    public static let shared = TTSPlayer()

    @Published public internal(set) var state: TTSPlaybackState = .idle
    @Published public internal(set) var currentSentenceIndex = 0
    @Published public internal(set) var totalSentences = 0
    @Published public internal(set) var currentSentence = ""
    @Published public internal(set) var timerMode: TTSTimerMode = .none
    @Published public var config: TTSConfig
    @Published public internal(set) var availableVoices: [TTSVoice] = []

    /// 兼容旧版语速属性 (对应 speechRateMultiplier)
    public var speechRate: Float {
        get { config.speechRateMultiplier }
        set {
            config.speechRateMultiplier = newValue
            saveConfig()
        }
    }

    /// 兼容旧版音高属性
    public var speechPitch: Float {
        get { config.speechPitch }
        set {
            config.speechPitch = newValue
            saveConfig()
        }
    }

    /// 兼容旧版睡眠定时器设置
    public func setSleepTimer(minutes: Int) {
        setMinuteTimer(minutes: minutes, finishChapterFirst: false)
    }

    /// 兼容旧版清除定时器
    public func clearSleepTimer() {
        clearTimer()
    }

    /// 兼容旧版剩余秒数属性
    public var timerRemainingSeconds: Int? {
        switch timerMode {
        case .none, .chapters:
            return nil

        case let .minutes(_, remaining, _):
            return remaining
        }
    }

    // 内部播放与媒体属性
    let synthesizer = AVSpeechSynthesizer()
    var sentences: [String] = []
    var currentBookTitle = ""
    var currentAuthor = ""
    var currentChapterTitle = ""
    var sleepTimerTask: Task<Void, Never>?
    var wasPlayingBeforeInterruption = false
    var currentUtteranceVolume: Float = 1.0

    // 跨章节与进度联动回调
    public var onSentenceChanged: ((_ index: Int, _ sentence: String) -> Void)?
    public var onChapterFinished: (() -> Void)?
    public var onRequestNextChapter: (() -> (title: String, content: String)?)?
    public var onRequestNextChapterAsync: (() async -> (title: String, content: String)?)?

    private static let configStorageKey = "io.github.theliser.legado.ttsConfig"

    override private init() {
        if let savedData = UserDefaults.standard.data(forKey: Self.configStorageKey),
           let decoded = try? JSONDecoder().decode(TTSConfig.self, from: savedData) {
            self.config = decoded
        } else {
            self.config = .default
        }

        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommands()
        setupAudioNotifications()
        fetchAvailableVoices()
    }

    /// 持久化朗读设置
    public func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: Self.configStorageKey)
        }
    }

    // MARK: - 播放控制接口

    /// 开始朗读指定文本内容
    public func startReading(
        content: String,
        bookTitle: String = "",
        chapterTitle: String = "",
        author: String = "",
        startIndex: Int = 0) {
        stopPlaybackInternal(clearTimer: false)

        self.currentBookTitle = bookTitle
        self.currentChapterTitle = chapterTitle
        self.currentAuthor = author

        self.sentences = Self.splitIntoSentences(content)
        self.totalSentences = sentences.count
        guard !sentences.isEmpty else {
            state = .idle
            return
        }

        let targetIndex = max(0, min(startIndex, sentences.count - 1))
        self.currentSentenceIndex = targetIndex
        playSentence(at: targetIndex)
    }

    /// 暂停朗读
    public func pause() {
        guard state == .playing else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        state = .paused
        updateNowPlayingInfo()
    }

    /// 恢复朗读
    public func resume() {
        if state == .paused {
            synthesizer.continueSpeaking()
            state = .playing
            updateNowPlayingInfo()
        } else if state == .idle, !sentences.isEmpty {
            playSentence(at: currentSentenceIndex)
        }
    }

    /// 停止朗读并清理定时器
    public func stop() {
        stopPlaybackInternal(clearTimer: true)
    }

    func stopPlaybackInternal(clearTimer: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        currentSentence = ""
        currentSentenceIndex = 0
        totalSentences = 0
        sentences = []
        if clearTimer {
            self.clearTimer()
        }
        clearNowPlayingInfo()
    }

    /// 跳转到指定句子
    public func jumpToSentence(at index: Int) {
        guard index >= 0, index < sentences.count else { return }
        currentSentenceIndex = index
        synthesizer.stopSpeaking(at: .immediate)
        playSentence(at: index)
    }

    /// 跳转下一句
    public func nextSentence() {
        if currentSentenceIndex + 1 < sentences.count {
            jumpToSentence(at: currentSentenceIndex + 1)
        } else {
            advanceToNextChapterOrStop()
        }
    }

    /// 跳转上一句
    public func previousSentence() {
        guard currentSentenceIndex > 0 else { return }
        jumpToSentence(at: currentSentenceIndex - 1)
    }

    // MARK: - 内部播放调度

    func playSentence(at index: Int) {
        guard index >= 0, index < sentences.count else {
            advanceToNextChapterOrStop()
            return
        }

        let sentence = sentences[index]
        self.currentSentence = sentence
        self.state = .playing
        onSentenceChanged?(index, sentence)
        updateNowPlayingInfo()

        let utterance = AVSpeechUtterance(string: sentence)

        // 选定声音
        if let voiceId = config.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }

        // 语速倍率映射 (标准 defaultRate 为基准)
        let baseRate = AVSpeechUtteranceDefaultSpeechRate
        let mappedRate = baseRate * config.speechRateMultiplier
        utterance.rate = min(max(mappedRate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)

        // 音高倍率映射
        utterance.pitchMultiplier = min(max(config.speechPitch, 0.5), 1.5)

        // 渐弱平滑音量控制
        utterance.volume = currentUtteranceVolume

        synthesizer.speak(utterance)
    }

    /// 当前章节朗读结束，进入下一章节或按定时规则停止
    func advanceToNextChapterOrStop() {
        // 1. 检查章节模式倒计时
        if case let .chapters(total, remaining) = timerMode {
            if remaining <= 1 {
                // 章节倒计时归零，停止播放
                clearTimer()
                stop()
                return
            } else {
                timerMode = .chapters(totalChapters: total, remainingChapters: remaining - 1)
            }
        }

        // 2. 检查分钟倒计时中「读完本章再停」标记
        if case let .minutes(_, remainingSeconds, finishChapterFirst) = timerMode,
           finishChapterFirst, remainingSeconds <= 0 {
            clearTimer()
            stop()
            return
        }

        // 3. 跨章节连续无缝听书
        onChapterFinished?()
        if let requestAsync = onRequestNextChapterAsync {
            Task { [weak self] in
                if let nextChapter = await requestAsync() {
                    self?.startReading(
                        content: nextChapter.content,
                        bookTitle: self?.currentBookTitle ?? "",
                        chapterTitle: nextChapter.title,
                        author: self?.currentAuthor ?? "",
                        startIndex: 0)
                } else {
                    self?.stop()
                }
            }
        } else if let nextChapter = onRequestNextChapter?() {
            startReading(
                content: nextChapter.content,
                bookTitle: currentBookTitle,
                chapterTitle: nextChapter.title,
                author: currentAuthor,
                startIndex: 0)
        } else {
            stop()
        }
    }

    // MARK: - 可用声音枚举

    public func fetchAvailableVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let mapped = allVoices.map { voice -> TTSVoice in
            let quality: String
            switch voice.quality {
            case .enhanced:
                quality = "高音质"

            case .premium:
                quality = "极佳"

            default:
                quality = "标准"
            }
            return TTSVoice(
                id: voice.identifier,
                name: voice.name,
                language: voice.language,
                qualityDescription: quality)
        }

        // 中文语系置顶排序
        self.availableVoices = mapped.sorted { firstVoice, secondVoice in
            if firstVoice.isChinese, !secondVoice.isChinese {
                return true
            }
            if !firstVoice.isChinese, secondVoice.isChinese {
                return false
            }
            return firstVoice.name.localizedStandardCompare(secondVoice.name) == .orderedAscending
        }
    }

    /// 智能断句：按换行与常用标点符号切分为独立朗读单元
    public static func splitIntoSentences(_ text: String) -> [String] {
        var result: [String] = []
        let rawParagraphs = text.components(separatedBy: .newlines)

        for paragraph in rawParagraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let pattern = "[^。！？!?；;]+[。！？!?；;]?"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsString = trimmed as NSString
                let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
                if !matches.isEmpty {
                    for match in matches {
                        let sub = nsString.substring(with: match.range).trimmingCharacters(in: .whitespaces)
                        if !sub.isEmpty {
                            result.append(sub)
                        }
                    }
                    continue
                }
            }
            result.append(trimmed)
        }
        return result
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSPlayer: @preconcurrency AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didFinish _: AVSpeechUtterance) {
        guard state == .playing else { return }
        if currentSentenceIndex + 1 < sentences.count {
            currentSentenceIndex += 1
            playSentence(at: currentSentenceIndex)
        } else {
            advanceToNextChapterOrStop()
        }
    }

    public func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didCancel _: AVSpeechUtterance) {
        // 取消事件
    }
}
