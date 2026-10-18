import AVFoundation
import Foundation
import MediaPlayer

/// 朗读状态枚举
public enum TTSPlaybackState: String, Sendable {
    case idle
    case playing
    case paused
}

/// 基于 AVSpeechSynthesizer 与 NowPlayingInfoCenter 的原生语音朗读引擎
@MainActor
public final class TTSPlayer: NSObject, ObservableObject {
    public static let shared = TTSPlayer()

    @Published public private(set) var state: TTSPlaybackState = .idle
    @Published public private(set) var currentSentenceIndex = 0
    @Published public private(set) var totalSentences = 0
    @Published public private(set) var currentSentence = ""
    @Published public var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published public var speechPitch: Float = 1.0
    @Published public private(set) var timerRemainingSeconds: Int?

    private let synthesizer = AVSpeechSynthesizer()
    private var sentences: [String] = []
    private var currentBookTitle = ""
    private var currentAuthor = ""
    private var currentChapterTitle = ""
    private var sleepTimerTask: Task<Void, Never>?

    override private init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommands()
    }

    // MARK: - 音频会话与锁屏控制中心

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[TTSPlayer] Failed to activate audio session: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.state == .playing {
                self.pause()
            } else if self.state == .paused {
                self.resume()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.nextSentence()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.previousSentence()
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentChapterTitle.isEmpty ? currentBookTitle : currentChapterTitle,
            MPMediaItemPropertyArtist: currentAuthor.isEmpty ? "Legado 朗读" : currentAuthor,
            MPMediaItemPropertyAlbumTitle: currentBookTitle,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
        ]
        if totalSentences > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(totalSentences)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentSentenceIndex)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 播放控制接口

    /// 开始朗读指定文本内容
    public func startReading(
        content: String,
        bookTitle: String = "",
        chapterTitle: String = "",
        author: String = "",
        startIndex: Int = 0) {
        stop()

        self.currentBookTitle = bookTitle
        self.currentChapterTitle = chapterTitle
        self.currentAuthor = author

        // 智能断句：按换行、句号、叹号、问号切分
        self.sentences = Self.splitIntoSentences(content)
        self.totalSentences = sentences.count
        guard !sentences.isEmpty else { return }

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

    /// 停止朗读
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        currentSentence = ""
        currentSentenceIndex = 0
        totalSentences = 0
        sentences = []
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        timerRemainingSeconds = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// 跳转下一句
    public func nextSentence() {
        guard currentSentenceIndex + 1 < sentences.count else { return }
        currentSentenceIndex += 1
        synthesizer.stopSpeaking(at: .immediate)
        playSentence(at: currentSentenceIndex)
    }

    /// 跳转上一句
    public func previousSentence() {
        guard currentSentenceIndex > 0 else { return }
        currentSentenceIndex -= 1
        synthesizer.stopSpeaking(at: .immediate)
        playSentence(at: currentSentenceIndex)
    }

    // MARK: - 定时关闭

    /// 设置倒计时定时关闭（分钟）
    public func setSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        guard minutes > 0 else {
            timerRemainingSeconds = nil
            return
        }

        var remaining = minutes * 60
        self.timerRemainingSeconds = remaining

        sleepTimerTask = Task { [weak self] in
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1
                await MainActor.run {
                    self?.timerRemainingSeconds = remaining
                    if remaining <= 0 {
                        self?.pause()
                    }
                }
            }
        }
    }

    public func clearSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        timerRemainingSeconds = nil
    }

    // MARK: - 内部播放调度

    private func playSentence(at index: Int) {
        guard index >= 0, index < sentences.count else {
            stop()
            return
        }

        let sentence = sentences[index]
        self.currentSentence = sentence
        self.state = .playing
        updateNowPlayingInfo()

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch

        synthesizer.speak(utterance)
    }

    /// 智能断句：按换行与常用标点符号切分为独立朗读单元
    public static func splitIntoSentences(_ text: String) -> [String] {
        var result: [String] = []
        let rawParagraphs = text.components(separatedBy: .newlines)

        for paragraph in rawParagraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 按标点符号进一步切分保证逐句高亮与自然换气
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
            stop()
        }
    }

    public func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didCancel _: AVSpeechUtterance) {
        // 取消事件
    }
}
