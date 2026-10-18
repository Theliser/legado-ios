import SwiftUI

// MARK: - TTSControlSheet 声音与语速调节视图扩展

extension TTSControlSheet {
    var voiceAndRateContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 语速倍率微调
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("语速倍率")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.2fx", ttsPlayer.config.speechRateMultiplier))
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.tint)
                    }

                    // 快捷倍率标签
                    HStack(spacing: 8) {
                        ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                            Button {
                                ttsPlayer.config.speechRateMultiplier = Float(rate)
                                ttsPlayer.saveConfig()
                            } label: {
                                Text(String(format: "%.2fx", rate))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(
                                        abs(Double(ttsPlayer.config.speechRateMultiplier) - rate) < 0.05 ? 0.2 : 0.06))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Slider(
                        value: Binding(
                            get: { Double(ttsPlayer.config.speechRateMultiplier) },
                            set: {
                                ttsPlayer.config.speechRateMultiplier = Float($0)
                                ttsPlayer.saveConfig()
                            }),
                        in: 0.5 ... 2.0,
                        step: 0.05)
                        .tint(.accentColor)
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5))

                // 音高微调
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("语调音高")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.2f", ttsPlayer.config.speechPitch))
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.tint)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(ttsPlayer.config.speechPitch) },
                            set: {
                                ttsPlayer.config.speechPitch = Float($0)
                                ttsPlayer.saveConfig()
                            }),
                        in: 0.5 ... 1.5,
                        step: 0.05)
                        .tint(.accentColor)
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5))

                // 系统声音选择
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("系统朗读角色")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(ttsPlayer.availableVoices.count) 种声音可用")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(ttsPlayer.availableVoices.prefix(12)) { voice in
                        Button {
                            ttsPlayer.config.voiceIdentifier = voice.id
                            ttsPlayer.saveConfig()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(voice.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        if voice.isChinese {
                                            Text("中文")
                                                .font(.system(size: 10).weight(.semibold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.15))
                                                .foregroundStyle(.tint)
                                                .clipShape(Capsule())
                                        }

                                        Text(voice.qualityDescription)
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.06))
                                            .foregroundStyle(.secondary)
                                            .clipShape(Capsule())
                                    }

                                    Text(voice.languageDisplayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if ttsPlayer.config.voiceIdentifier == voice.id
                                    || (ttsPlayer.config.voiceIdentifier == nil && voice.isChinese) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                        .font(.subheadline)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if voice.id != ttsPlayer.availableVoices.prefix(12).last?.id {
                            Divider()
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
}
