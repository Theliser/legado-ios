import AVFoundation
import SwiftUI

/// 朗读控制与睡眠定时器半屏面板 (基于 Apple 原生 Liquid Glass 规范设计)
public struct TTSControlSheet: View {
    @ObservedObject var ttsPlayer: TTSPlayer = .shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0 // 0: 定时关闭, 1: 声音与语速
    @State private var timerModeTab = 0 // 0: 按分钟, 1: 按章节
    @State private var customMinutes: Double = 30
    @State private var customChapters: Double = 1

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 顶部液态玻璃分段控制器
                Picker("分类", selection: $selectedTab) {
                    Text("睡眠定时").tag(0)
                    Text("声音与语速").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if selectedTab == 0 {
                    timerContent
                } else {
                    voiceAndRateContent
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("朗读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        ttsPlayer.saveConfig()
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - 睡眠定时器设置面板

    private var timerContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 当前生效定时提示条
                if ttsPlayer.timerMode.isActive {
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .foregroundStyle(.tint)
                            .font(.headline)
                        Text(ttsPlayer.timerMode.detailDescription)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Button(role: .destructive) {
                            ttsPlayer.clearTimer()
                        } label: {
                            Text("取消定时")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                }

                // 模式选择：按时间 vs 按章节
                Picker("定时模式", selection: $timerModeTab) {
                    Text("按时间倒计时").tag(0)
                    Text("按章节数倒计时").tag(1)
                }
                .pickerStyle(.segmented)

                if timerModeTab == 0 {
                    minuteTimerSection
                } else {
                    chapterTimerSection
                }

                // 高级选项
                VStack(spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { ttsPlayer.config.finishCurrentChapterAfterTimer },
                        set: {
                            ttsPlayer.config.finishCurrentChapterAfterTimer = $0
                            ttsPlayer.saveConfig()
                        })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("读完本章再停")
                                    .font(.subheadline.weight(.medium))
                                Text("倒计时结束后不截断，平滑读完当前章节后停止")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    Divider()

                    Toggle(isOn: Binding(
                        get: { ttsPlayer.config.isFadeOutEnabled },
                        set: {
                            ttsPlayer.config.isFadeOutEnabled = $0
                            ttsPlayer.saveConfig()
                        })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("渐弱停止")
                                    .font(.subheadline.weight(.medium))
                                Text("倒计时最后 10 秒平滑淡出音量，避免骤停打扰入睡")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    private var minuteTimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷预设时长")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // 预设时长快捷胶囊按钮
            let minutePresets = [15, 30, 45, 60, 90, 120]
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                ForEach(minutePresets, id: \.self) { min in
                    Button {
                        ttsPlayer.setMinuteTimer(
                            minutes: min,
                            finishChapterFirst: ttsPlayer.config.finishCurrentChapterAfterTimer)
                    } label: {
                        Text("\(min) 分钟")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("自定义时长：\(Int(customMinutes)) 分钟")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("设定") {
                        ttsPlayer.setMinuteTimer(
                            minutes: Int(customMinutes),
                            finishChapterFirst: ttsPlayer.config.finishCurrentChapterAfterTimer)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                }

                Slider(value: $customMinutes, in: 5 ... 180, step: 5)
                    .tint(.accentColor)
            }
            .padding(.top, 4)
        }
    }

    private var chapterTimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按章节数定时")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let chapterPresets = [1, 2, 3, 5, 8, 10]
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                ForEach(chapterPresets, id: \.self) { chapterCount in
                    Button {
                        ttsPlayer.setChapterTimer(chapters: chapterCount)
                    } label: {
                        Text("\(chapterCount) 章后停止")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("自定义章节数：\(Int(customChapters)) 章")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("设定") {
                        ttsPlayer.setChapterTimer(chapters: Int(customChapters))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                }

                Slider(value: $customChapters, in: 1 ... 20, step: 1)
                    .tint(.accentColor)
            }
            .padding(.top, 4)
        }
    }
}
