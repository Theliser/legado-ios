import SwiftUI

/// 系统设置主视图 (遵循 MVI 架构与原生 iOS 18 液态玻璃质感)
public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Form {

                // MARK: - WebDAV 云同步分区

                webDAVSection

                // MARK: - 语音朗读设置分区

                ttsSection

                // MARK: - 文本净化与规则分区

                purifySection

                // MARK: - 关于与系统架构分区

                aboutSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .onReceive(viewModel.effectPublisher) { effect in
                switch effect {
                case let .showToast(msg):
                    toastMessage = msg
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if toastMessage == msg {
                            toastMessage = nil
                        }
                    }

                case .hapticFeedback:
                    hapticTrigger.toggle()
                }
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - WebDAV 分区

    private var webDAVSection: some View {
        Section {
            TextField("服务器地址 (如坚果云或自建 NAS)", text: Binding(
                get: { viewModel.state.webDAVConfig.serverUrl },
                set: { viewModel.send(.updateWebDAVServer($0)) }))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("账号 / 邮箱", text: Binding(
                get: { viewModel.state.webDAVConfig.username },
                set: { viewModel.send(.updateWebDAVUsername($0)) }))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("应用独立密码", text: Binding(
                get: { viewModel.state.webDAVConfig.password },
                set: { viewModel.send(.updateWebDAVPassword($0)) }))

            TextField("远程存放目录", text: Binding(
                get: { viewModel.state.webDAVConfig.remoteDirectory },
                set: { viewModel.send(.updateWebDAVDirectory($0)) }))

            // 测试连接按钮
            Button {
                viewModel.send(.testWebDAVConnection)
            } label: {
                HStack {
                    if viewModel.state.isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在验证连接...")
                    } else {
                        Image(systemName: "network.badge.shield.half.filled")
                        Text("测试服务器连接")
                    }
                }
                .font(.subheadline.weight(.medium))
            }
            .disabled(viewModel.state.isTestingConnection)

            // 备份与还原操作行
            HStack(spacing: 12) {
                Button {
                    viewModel.send(.backupToWebDAV)
                } label: {
                    HStack {
                        if viewModel.state.isBackingUp {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise.icloud.fill")
                        }
                        Text("立即备份")
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.state.isBackingUp)

                Button {
                    viewModel.send(.restoreFromWebDAV)
                } label: {
                    HStack {
                        if viewModel.state.isRestoring {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.down.fill")
                        }
                        Text("从云端还原")
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.state.isRestoring)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            if let summary = viewModel.state.lastBackupSummary {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近备份已完成")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("包含 \(summary.bookCount) 本书，\(summary.sourceCount) 个书源 (\(summary.dataSizeBytes / 1024) KB)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("WebDAV 云备份同步", systemImage: "icloud")
        } footer: {
            Text("支持坚果云、Nextcloud、群晖 WebDAV 服务，自动无损加密打包书架与书源配置。")
        }
    }

    // MARK: - 朗读设置分区

    private var ttsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("朗读语速")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2fx", viewModel.state.speechRate * 2))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.state.speechRate) },
                        set: { viewModel.send(.updateSpeechRate(Float($0))) }),
                    in: 0.2 ... 0.8,
                    step: 0.05)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("语音音调")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", viewModel.state.speechPitch))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.state.speechPitch) },
                        set: { viewModel.send(.updateSpeechPitch(Float($0))) }),
                    in: 0.5 ... 1.5,
                    step: 0.1)
            }
            .padding(.vertical, 2)
        } header: {
            Label("语音朗读偏好 (TTS)", systemImage: "headphones")
        }
    }

    // MARK: - 净化分区

    private var purifySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("智能去广告与防盗水印净化")
                        .font(.subheadline.weight(.medium))
                    Text("自动剔除“本章未完请翻页”、推广外链与乱码广告行")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Label("正文净化规则", systemImage: "wand.and.stars")
        }
    }

    // MARK: - 关于分区

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0 (iOS 18+ 原生)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("视觉风格")
                Spacer()
                Text("Apple Liquid Glass / Vibrancy")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("架构设计")
                Spacer()
                Text("MVI + Clean Architecture")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("开源致敬")
                Spacer()
                Text("Legado (阅读 3.0)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("关于应用", systemImage: "info.circle")
        }
    }
}
