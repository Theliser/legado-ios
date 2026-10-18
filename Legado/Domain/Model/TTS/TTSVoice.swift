import AVFoundation
import Foundation

/// 系统朗读声音实体封装
public struct TTSVoice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let language: String
    public let qualityDescription: String

    public init(
        id: String,
        name: String,
        language: String,
        qualityDescription: String = "标准") {
        self.id = id
        self.name = name
        self.language = language
        self.qualityDescription = qualityDescription
    }

    /// 是否为中文语系
    public var isChinese: Bool {
        language.lowercased().hasPrefix("zh")
    }

    /// 语言友好展示名
    public var languageDisplayName: String {
        let locale = Locale(identifier: language)
        return locale.localizedString(forIdentifier: language) ?? language
    }
}
