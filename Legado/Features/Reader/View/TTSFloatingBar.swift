import SwiftUI

/// 朗读悬浮控制胶囊栏 (基于 iOS 原生液态玻璃与 Materials 质感设计)
public struct TTSFloatingBar: View {
    @ObservedObject var ttsPlayer: TTSPlayer = .shared
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 14) {
            // 左侧状态指示
            HStack(spacing: 6) {
                Image(systemName: ttsPlayer.state == .playing ? "speaker.wave.3.fill" : "speaker.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: ttsPlayer.state == .playing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ttsPlayer.state == .playing ? "正在朗读" : "已暂停")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)

                    if ttsPlayer.totalSentences > 0 {
                        Text("\(ttsPlayer.currentSentenceIndex + 1)/\(ttsPlayer.totalSentences) 句")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 70, alignment: .leading)

            Spacer()

            // 核心播放控制
            HStack(spacing: 16) {
                Button {
                    ttsPlayer.previousSentence()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Button {
                    if ttsPlayer.state == .playing {
                        ttsPlayer.pause()
                    } else {
                        ttsPlayer.resume()
                    }
                } label: {
                    Image(systemName: ttsPlayer.state == .playing ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }

                Button {
                    ttsPlayer.nextSentence()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            // 右侧语速与关闭
            HStack(spacing: 10) {
                // 语速菜单
                Menu {
                    Button("0.75x 缓慢") { ttsPlayer.speechRate = 0.4 }
                    Button("1.0x 标准") { ttsPlayer.speechRate = 0.5 }
                    Button("1.25x 稍快") { ttsPlayer.speechRate = 0.55 }
                    Button("1.5x 快速") { ttsPlayer.speechRate = 0.6 }
                } label: {
                    Text(rateLabel(for: ttsPlayer.speechRate))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }

                // 定时菜单
                Menu {
                    Button("不设置定时") { ttsPlayer.clearSleepTimer() }
                    Button("15 分钟后停止") { ttsPlayer.setSleepTimer(minutes: 15) }
                    Button("30 分钟后停止") { ttsPlayer.setSleepTimer(minutes: 30) }
                    Button("60 分钟后停止") { ttsPlayer.setSleepTimer(minutes: 60) }
                } label: {
                    Image(systemName: ttsPlayer.timerRemainingSeconds != nil ? "timer.circle.fill" : "timer")
                        .font(.subheadline)
                        .foregroundStyle(ttsPlayer.timerRemainingSeconds != nil ? Color.accentColor : Color.secondary)
                }

                // 关闭按钮
                Button {
                    ttsPlayer.stop()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .padding(.horizontal, 16)
    }

    private func rateLabel(for rate: Float) -> String {
        if rate <= 0.45 {
            return "0.75x"
        }
        if rate <= 0.52 {
            return "1.0x"
        }
        if rate <= 0.58 {
            return "1.25x"
        }
        return "1.5x"
    }
}
