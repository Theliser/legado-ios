import Foundation

/// 书源编辑页面意图（MVI Intent）
public enum BookSourceEditIntent: ViewIntent, Sendable {
    /// 加载指定书源（若为 nil 则为新建空白书源）
    case loadSource(BookSource?)
    /// 切换标签页
    case selectTab(BookSourceEditTab)
    /// 更新指定键值的字段文本
    case updateField(key: String, value: String)
    /// 激活当前正在编辑的输入框键名（用于语法助手胶囊插入）
    case setActiveField(key: String?)
    /// 插入语法助手标记
    case insertSyntaxChip(token: String)
    /// 更新布尔开关（例如 enabled, enabledExplore）
    case toggleBoolean(key: String, value: Bool)
    /// 更新书源类型 (0: 文本, 1: 音频, 2: 漫画)
    case updateSourceType(Int)
    /// 切换表单/JSON源码编辑模式
    case toggleJsonMode
    /// 更新源码 JSON 文本
    case updateRawJson(String)
    /// 格式化美化 JSON
    case formatJson
    /// 从外部文本或剪贴板覆盖导入 JSON
    case importJsonFromText(String)
    /// 保存书源
    case save
    /// 保存并打开调试控制台
    case saveAndDebug
    /// 直接以当前草稿打开调试控制台
    case openDebug
    /// 关闭调试控制台
    case closeDebug
    /// 请求退出（检查 dirty 状态）
    case requestDismiss
    /// 确认放弃未保存的修改
    case confirmDiscard
    /// 取消放弃，继续编辑
    case cancelDiscard
    /// 清除错误提示
    case clearError
}

/// 书源编辑一次性副作用（MVI Effect）
public enum BookSourceEditEffect: ViewEffect, Sendable {
    case savedSuccessfully(BookSource)
    case openDebug(BookSource)
    case dismiss
    case showToast(String)
    case hapticFeedback
    case copyToClipboard(String)
}
