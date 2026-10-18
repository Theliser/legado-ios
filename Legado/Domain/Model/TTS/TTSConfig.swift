import Foundation

/// 朗读全局配置实体
public struct TTSConfig: Equatable, Codable, Sendable {
    /// 语速倍率：0.5x ~ 2.0x (默认为 1.0x 标准语速)
    public var speechRateMultiplier: Float
    /// 音高倍率：0.5 ~ 1.5 (默认为 1.0 标准音高)
    public var speechPitch: Float
    /// 用户选定的声音标识符
    public var voiceIdentifier: String?
    /// 定时到点后是否播完本章再停
    public var finishCurrentChapterAfterTimer: Bool
    /// 定时结束前是否平滑渐弱停止
    public var isFadeOutEnabled: Bool

    public init(
        speechRateMultiplier: Float = 1.0,
        speechPitch: Float = 1.0,
        voiceIdentifier: String? = nil,
        finishCurrentChapterAfterTimer: Bool = false,
        isFadeOutEnabled: Bool = true) {
        self.speechRateMultiplier = min(max(speechRateMultiplier, 0.5), 2.0)
        self.speechPitch = min(max(speechPitch, 0.5), 1.5)
        self.voiceIdentifier = voiceIdentifier
        self.finishCurrentChapterAfterTimer = finishCurrentChapterAfterTimer
        self.isFadeOutEnabled = isFadeOutEnabled
    }

    public static let `default` = TTSConfig()
}
