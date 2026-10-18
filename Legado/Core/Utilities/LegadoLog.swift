import Foundation
import os

/// Legado 全局结构化统一日志门面，基于 Apple 官方 `os.Logger` 深度集成
public enum LegadoLog {
    private static let subsystem = "io.github.theliser.legado"

    /// 网络请求与字符集解码日志
    public static let network = Logger(subsystem: subsystem, category: "Network")

    /// 书源规则解析器与 JavaScript 执行引擎日志
    public static let ruleEngine = Logger(subsystem: subsystem, category: "RuleEngine")

    /// 阅读器排版引擎、分页计算与章节预加载日志
    public static let reader = Logger(subsystem: subsystem, category: "Reader")

    /// SwiftData 本地持久化与数据仓库 CRUD 日志
    public static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// 语音合成 TTS 播放、分句与计时器日志
    public static let tts = Logger(subsystem: subsystem, category: "TTS")

    /// WebDAV 云同步、备份与恢复流水线日志
    public static let webdav = Logger(subsystem: subsystem, category: "WebDAV")

    /// 依赖注入容器生命周期与组件装配日志
    public static let container = Logger(subsystem: subsystem, category: "Container")

    /// App 生命周期与通用全局事件日志
    public static let general = Logger(subsystem: subsystem, category: "General")
}
