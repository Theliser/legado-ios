import CryptoKit
import Foundation

/// 章节领域模型 (对齐 Android Legado BookChapter.kt)
public struct Chapter: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(bookUrl)_\(index)"
    }

    /// 章节正文 URL
    public var url: String
    /// 章节标题
    public var title: String
    /// 所属书籍 URL
    public var bookUrl: String
    /// 章节索引 (从 0 开始)
    public var index: Int
    /// 是否是卷名
    public var isVolume: Bool
    /// 目录层级，0 为顶层
    public var tocLevel: Int
    /// 用来拼接相对 URL 的基础地址
    public var baseUrl: String
    /// 是否 VIP 章节
    public var isVip: Bool
    /// 是否已购买
    public var isPay: Bool
    /// 音频真实 URL
    public var resourceUrl: String?
    /// 更新时间或其他章节附加信息
    public var tag: String?
    /// 本章节字数描述
    public var wordCount: String?
    /// 章节起始位置 (本地书籍)
    public var start: Int64?
    /// 章节终止位置 (本地书籍)
    public var end: Int64?
    /// EPUB 当前章节 fragmentId
    public var startFragmentId: String?
    /// EPUB 下一章节 fragmentId
    public var endFragmentId: String?
    /// 自定义规则变量 JSON
    public var variable: String?
    /// 段评图标 URL
    public var reviewImg: String?
    /// 标题 MD5 缓存
    public var titleMD5: String?
    /// 是否已下载缓存至本地
    public var isCached: Bool

    public init(
        url: String,
        title: String,
        bookUrl: String,
        index: Int,
        isVolume: Bool = false,
        tocLevel: Int = 0,
        baseUrl: String = "",
        isVip: Bool = false,
        isPay: Bool = false,
        resourceUrl: String? = nil,
        tag: String? = nil,
        wordCount: String? = nil,
        start: Int64? = nil,
        end: Int64? = nil,
        startFragmentId: String? = nil,
        endFragmentId: String? = nil,
        variable: String? = nil,
        reviewImg: String? = nil,
        titleMD5: String? = nil,
        isCached: Bool = false) {
        self.url = url
        self.title = title
        self.bookUrl = bookUrl
        self.index = index
        self.isVolume = isVolume
        self.tocLevel = tocLevel
        self.baseUrl = baseUrl
        self.isVip = isVip
        self.isPay = isPay
        self.resourceUrl = resourceUrl
        self.tag = tag
        self.wordCount = wordCount
        self.start = start
        self.end = end
        self.startFragmentId = startFragmentId
        self.endFragmentId = endFragmentId
        self.variable = variable
        self.reviewImg = reviewImg
        self.titleMD5 = titleMD5
        self.isCached = isCached
    }

    public init(
        bookUrl: String,
        title: String,
        url: String,
        index: Int,
        isVip: Bool = false,
        isVolume: Bool = false,
        isCached: Bool = false) {
        self.init(
            url: url,
            title: title,
            bookUrl: bookUrl,
            index: index,
            isVolume: isVolume,
            tocLevel: 0,
            baseUrl: "",
            isVip: isVip,
            isPay: false,
            resourceUrl: nil,
            tag: nil,
            wordCount: nil,
            start: nil,
            end: nil,
            startFragmentId: nil,
            endFragmentId: nil,
            variable: nil,
            reviewImg: nil,
            titleMD5: nil,
            isCached: isCached)
    }

    /// 获取解析后的完整绝对 URL
    public func getAbsoluteURL() -> String {
        if url.hasPrefix(title) && isVolume {
            return baseUrl
        }
        if let commaIndex = url.firstIndex(of: ",") {
            let before = String(url[..<commaIndex])
            let after = String(url[commaIndex...])
            let absBefore = AnalyzeUrl.resolveAbsoluteUrl(before, baseUrl: baseUrl)
            return "\(absBefore)\(after)"
        }
        return AnalyzeUrl.resolveAbsoluteUrl(url, baseUrl: baseUrl)
    }

    /// 唯一主键字符
    public func primaryStr() -> String {
        bookUrl + url
    }

    /// 获取缓存文件名 (对齐 Android Legado getFileName)
    public mutating func getFileName(suffix: String = "nb") -> String {
        ensureTitleMD5Init()
        return String(format: "%05d-%@.%@", index, titleMD5 ?? "", suffix)
    }

    /// 获取章节对应混淆字体名
    public mutating func getFontName() -> String {
        ensureTitleMD5Init()
        return String(format: "%05d-%@.ttf", index, titleMD5 ?? "")
    }

    private mutating func ensureTitleMD5Init() {
        if titleMD5 == nil || titleMD5?.isEmpty == true {
            let digest = Insecure.MD5.hash(data: Data(title.utf8))
            titleMD5 = digest.map { String(format: "%02hhx", $0) }.joined()
        }
    }
}

/// 兼容 Android 命名习惯的领域别名
public typealias BookChapter = Chapter
