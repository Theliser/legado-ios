import Foundation
import UIKit

/// 阅读器用户离散交互意图
public enum ReaderIntent: ViewIntent, Equatable, Sendable {
    /// 载入并排版指定章节
    case loadChapter(Int)
    /// 下一页 (最后一页时自动进入下一章)
    case nextPage
    /// 上一页 (第一页时自动进入上一章末尾)
    case prevPage
    /// 跳转到当前章节特定页码
    case jumpToPage(Int)
    /// 切换 HUD 唤出/隐藏
    case toggleHUD
    /// 隐藏 HUD
    case hideHUD
    /// 打开目录抽屉
    case openToc
    /// 关闭目录抽屉
    case closeToc
    /// 打开排版与主题设置抽屉
    case openConfig
    /// 关闭排版设置
    case closeConfig
    /// 调整字号增减
    case changeFontSize(delta: CGFloat)
    /// 切换配色主题
    case selectTheme(ReaderTheme)
    /// 屏幕尺寸尺寸更新重新排版
    case updateScreenBounds(CGRect)
}

/// 阅读器副作用
public enum ReaderEffect: ViewEffect, Equatable, Sendable {
    case showToast(String)
    case hapticFeedback
    case navigateBack
}
