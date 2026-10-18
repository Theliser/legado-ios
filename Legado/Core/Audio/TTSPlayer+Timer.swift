import Foundation

// MARK: - 睡眠定时器与渐弱停止调度扩展

public extension TTSPlayer {
    /// 开启分钟倒计时
    func setMinuteTimer(minutes: Int, finishChapterFirst: Bool = false) {
        sleepTimerTask?.cancel()
        guard minutes > 0 else {
            clearTimer()
            return
        }

        let totalSeconds = minutes * 60
        self.currentUtteranceVolume = 1.0
        self.timerMode = .minutes(
            totalMinutes: minutes,
            remainingSeconds: totalSeconds,
            finishChapterFirst: finishChapterFirst)

        sleepTimerTask = Task { [weak self] in
            var remaining = totalSeconds
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1

                await MainActor.run {
                    guard let self else { return }
                    // 渐弱平滑淡出：最后 10 秒音量线性降低至 0.1
                    if self.config.isFadeOutEnabled && remaining <= 10 {
                        self.currentUtteranceVolume = max(0.1, Float(remaining) / 10.0)
                    } else {
                        self.currentUtteranceVolume = 1.0
                    }

                    self.timerMode = .minutes(
                        totalMinutes: minutes,
                        remainingSeconds: remaining,
                        finishChapterFirst: finishChapterFirst)

                    if remaining <= 0 {
                        if finishChapterFirst {
                            // 保持播放状态，等待本章读完在 advanceToNextChapterOrStop 中停止
                            self.currentUtteranceVolume = 1.0
                        } else {
                            self.clearTimer()
                            self.pause()
                        }
                    }
                }
            }
        }
    }

    /// 开启按章节数倒计时
    func setChapterTimer(chapters: Int) {
        sleepTimerTask?.cancel()
        guard chapters > 0 else {
            clearTimer()
            return
        }
        self.currentUtteranceVolume = 1.0
        self.timerMode = .chapters(totalChapters: chapters, remainingChapters: chapters)
    }

    /// 清理或取消当前定时器
    func clearTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        timerMode = .none
        currentUtteranceVolume = 1.0
    }
}
