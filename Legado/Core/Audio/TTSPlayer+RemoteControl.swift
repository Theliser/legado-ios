import AVFoundation
import MediaPlayer
import UIKit

// MARK: - 锁屏媒体控制、控制中心与音频会话通知联动

extension TTSPlayer {
    func setupAudioSession() {
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

    func setupAudioNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main) { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self, let userInfo = notification.userInfo,
                          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                        return
                    }

                    switch type {
                    case .began:
                        self.wasPlayingBeforeInterruption = (self.state == .playing)
                        if self.state == .playing {
                            self.pause()
                        }

                    case .ended:
                        guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume), self.wasPlayingBeforeInterruption {
                            self.resume()
                        }
                        self.wasPlayingBeforeInterruption = false

                    @unknown default:
                        break
                    }
                }
            }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main) { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self, let userInfo = notification.userInfo,
                          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                        return
                    }

                    // 耳机断开拔出时自动暂停
                    if reason == .oldDeviceUnavailable, self.state == .playing {
                        self.pause()
                    }
                }
            }
    }

    func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.state == .playing {
                self.pause()
            } else {
                self.resume()
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.nextSentence()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.previousSentence()
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            let target = min(self.currentSentenceIndex + 3, max(self.sentences.count - 1, 0))
            self.jumpToSentence(at: target)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            let target = max(self.currentSentenceIndex - 3, 0)
            self.jumpToSentence(at: target)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetIndex = Int(positionEvent.positionTime)
            self.jumpToSentence(at: targetIndex)
            return .success
        }
    }

    func updateNowPlayingInfo() {
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

        // 绘制锁屏高保真液态卡片艺术封面
        let artworkImage = generateLockScreenArtwork(
            title: currentBookTitle.isEmpty ? "Legado" : currentBookTitle,
            subtitle: currentChapterTitle)
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
            artworkImage
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func generateLockScreenArtwork(title: String, subtitle: String) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 渐变底色
            let colors = [
                UIColor(red: 0.12, green: 0.16, blue: 0.28, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1.0).cgColor,
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 512, y: 512),
                    options: [])
            }

            // 装饰圆角外框
            let rect = CGRect(x: 24, y: 24, width: 464, height: 464)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 36)
            UIColor.white.withAlphaComponent(0.12).setStroke()
            path.lineWidth = 2
            path.stroke()

            // 品牌标识
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                .foregroundColor: UIColor.systemBlue,
            ]
            let badgeStr = "LEGADO AUDIO"
            badgeStr.draw(at: CGPoint(x: 48, y: 56), withAttributes: badgeAttributes)

            // 书名绘制
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let titleRect = CGRect(x: 48, y: 180, width: 416, height: 160)
            title.draw(in: titleRect, withAttributes: titleAttributes)

            // 章节小标题绘制
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ]
            let subRect = CGRect(x: 48, y: 360, width: 416, height: 80)
            subtitle.draw(in: subRect, withAttributes: subtitleAttributes)
        }
    }
}
