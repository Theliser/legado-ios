import Foundation

/// 朗读定时模式枚举
public enum TTSTimerMode: Equatable, Sendable {
    /// 未开启定时
    case none
    /// 按分钟倒计时：totalMinutes 为总分钟，remainingSeconds 为剩余秒数，finishChapterFirst 为到点后是否读完本章再停
    case minutes(totalMinutes: Int, remainingSeconds: Int, finishChapterFirst: Bool)
    /// 按章节数倒计时：totalChapters 为总章节数，remainingChapters 为剩余章节数
    case chapters(totalChapters: Int, remainingChapters: Int)

    /// 定时器是否处于生效状态
    public var isActive: Bool {
        switch self {
        case .none:
            return false

        case let .minutes(_, remainingSeconds, _):
            return remainingSeconds > 0

        case let .chapters(_, remainingChapters):
            return remainingChapters > 0
        }
    }

    /// 定时状态的简短描述（用于胶囊栏与 HUD 徽标）
    public var shortDescription: String? {
        switch self {
        case .none:
            return nil

        case let .minutes(_, remainingSeconds, finishChapterFirst):
            if remainingSeconds <= 0, finishChapterFirst {
                return "读完停"
            }
            let mins = remainingSeconds / 60
            let secs = remainingSeconds % 60
            return String(format: "%02d:%02d", mins, secs)

        case let .chapters(_, remainingChapters):
            return "剩\(remainingChapters)章"
        }
    }

    /// 详细文字描述
    public var detailDescription: String {
        switch self {
        case .none:
            return "未设置定时"

        case let .minutes(totalMinutes, remainingSeconds, finishChapterFirst):
            let mins = remainingSeconds / 60
            let secs = remainingSeconds % 60
            let timeStr = String(format: "%02d:%02d", mins, secs)
            if finishChapterFirst {
                return "定时 \(totalMinutes) 分钟 (剩余 \(timeStr)，读完本章后停止)"
            } else {
                return "定时 \(totalMinutes) 分钟 (剩余 \(timeStr))"
            }

        case let .chapters(totalChapters, remainingChapters):
            return "定时 \(totalChapters) 章 (剩余 \(remainingChapters) 章)"
        }
    }
}
