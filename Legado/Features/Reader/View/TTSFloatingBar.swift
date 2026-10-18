import SwiftUI

/// 朗读悬浮控制胶囊栏 (基于 iOS 原生液态玻璃与 Materials 质感设计)
public struct TTSFloatingBar: View {
    @ObservedObject var ttsPlayer: TTSPlayer = .shared
    @State private var isControlSheetPresented = false
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 12) {
            // 左侧状态指示与定时标签
            HStack(spacing: 8) {
                Image(systemName: ttsPlayer.state == .playing ? "speaker.wave.3.fill" : "speaker.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: ttsPlayer.state == .playing)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(ttsPlayer.state == .playing ? "正在朗读" : "已暂停")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let timerText = ttsPlayer.timerMode.shortDescription {
                            Text(timerText)
                                .font(.system(size: 9).weight(.bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.18))
                                .foregroundStyle(.tint)
                                .clipShape(Capsule())
                        }
                    }

                    if ttsPlayer.totalSentences > 0 {
                        Text("\(ttsPlayer.currentSentenceIndex + 1)/\(ttsPlayer.totalSentences) 句")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 80, alignment: .leading)

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

            // 右侧设置面板触发与关闭
            HStack(spacing: 8) {
                // 打开朗读与睡眠定时器全功能面板
                Button {
                    isControlSheetPresented = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: ttsPlayer.timerMode.isActive ? "timer.circle.fill" : "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                        Text(String(format: "%.2fx", ttsPlayer.config.speechRateMultiplier))
                            .font(.system(size: 10).weight(.bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .foregroundStyle(ttsPlayer.timerMode.isActive ? Color.accentColor : Color.primary)
                    .clipShape(Capsule())
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
        .sheet(isPresented: $isControlSheetPresented) {
            TTSControlSheet()
        }
    }
}
