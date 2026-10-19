import Foundation

/// Legado 3.0 书源核心领域模型 (全面对标 Android Legado BookSource.kt)
public struct BookSource: Identifiable, Codable, Equatable, Sendable, BaseSource {
    public var id: String {
        bookSourceUrl
    }

    /// 地址，包括 http/https
    public var bookSourceUrl: String
    /// 名称
    public var bookSourceName: String
    /// 分组
    public var bookSourceGroup: String?
    /// 类型，0 文本，1 音频, 2 图片, 3 文件, 4 视频
    public var bookSourceType: Int?
    /// 详情页url正则
    public var bookUrlPattern: String?
    /// 手动排序编号
    public var customOrder: Int?
    /// 是否启用
    public var enabled: Bool?
    /// 启用发现
    public var enabledExplore: Bool?
    /// js库
    public var jsLib: String?
    /// 启用 CookieJar 自动保存每次请求的cookie
    public var enabledCookieJar: Bool?
    /// 并发率
    public var concurrentRate: String?
    /// 请求头
    public var header: String?
    /// 登录地址
    public var loginUrl: String?
    /// 登录UI
    public var loginUi: String?
    /// 登录检测js
    public var loginCheckJs: String?
    /// 封面解密js
    public var coverDecodeJs: String?
    /// 注释
    public var bookSourceComment: String?
    /// 自定义变量说明
    public var variableComment: String?
    /// 最后更新时间，用于排序
    public var lastUpdateTime: Int64?
    /// 响应时间，用于排序
    public var respondTime: Int64?
    /// 智能排序的权重
    public var weight: Int?
    /// 发现url
    public var exploreUrl: String?
    /// 发现筛选规则
    public var exploreScreen: String?
    /// 发现规则
    public var ruleExplore: ExploreRule?
    /// 搜索url
    public var searchUrl: String?
    /// 搜索规则
    public var ruleSearch: SearchRule?
    /// 书籍信息页规则
    public var ruleBookInfo: BookInfoRule?
    /// 目录页规则
    public var ruleToc: TocRule?
    /// 正文页规则
    public var ruleContent: ContentRule?
    /// 段评规则
    public var ruleReview: ReviewRule?
    /// 是否监听事件来执行回调规则
    public var eventListener: Bool?
    /// 由书源控制的自定义按钮
    public var customButton: Bool?
    /// 首页模块定义，JSON数组
    public var homepageModules: String?

    public init(
        bookSourceUrl: String,
        bookSourceName: String,
        bookSourceGroup: String? = nil,
        bookSourceType: Int? = 0,
        bookUrlPattern: String? = nil,
        customOrder: Int? = 0,
        enabled: Bool? = true,
        enabledExplore: Bool? = true,
        jsLib: String? = nil,
        enabledCookieJar: Bool? = true,
        concurrentRate: String? = nil,
        header: String? = nil,
        loginUrl: String? = nil,
        loginUi: String? = nil,
        loginCheckJs: String? = nil,
        coverDecodeJs: String? = nil,
        bookSourceComment: String? = nil,
        variableComment: String? = nil,
        lastUpdateTime: Int64? = nil,
        respondTime: Int64? = 180_000,
        weight: Int? = 0,
        exploreUrl: String? = nil,
        exploreScreen: String? = nil,
        ruleExplore: ExploreRule? = nil,
        searchUrl: String? = nil,
        ruleSearch: SearchRule? = nil,
        ruleBookInfo: BookInfoRule? = nil,
        ruleToc: TocRule? = nil,
        ruleContent: ContentRule? = nil,
        ruleReview: ReviewRule? = nil,
        eventListener: Bool? = false,
        customButton: Bool? = false,
        homepageModules: String? = nil) {
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceName = bookSourceName
        self.bookSourceGroup = bookSourceGroup
        self.bookSourceType = bookSourceType
        self.bookUrlPattern = bookUrlPattern
        self.customOrder = customOrder
        self.enabled = enabled
        self.enabledExplore = enabledExplore
        self.jsLib = jsLib
        self.enabledCookieJar = enabledCookieJar
        self.concurrentRate = concurrentRate
        self.header = header
        self.loginUrl = loginUrl
        self.loginUi = loginUi
        self.loginCheckJs = loginCheckJs
        self.coverDecodeJs = coverDecodeJs
        self.bookSourceComment = bookSourceComment
        self.variableComment = variableComment
        self.lastUpdateTime = lastUpdateTime
        self.respondTime = respondTime
        self.weight = weight
        self.exploreUrl = exploreUrl
        self.exploreScreen = exploreScreen
        self.ruleExplore = ruleExplore
        self.searchUrl = searchUrl
        self.ruleSearch = ruleSearch
        self.ruleBookInfo = ruleBookInfo
        self.ruleToc = ruleToc
        self.ruleContent = ruleContent
        self.ruleReview = ruleReview
        self.eventListener = eventListener
        self.customButton = customButton
        self.homepageModules = homepageModules
    }

    public func getTag() -> String {
        bookSourceName
    }

    public func getKey() -> String {
        bookSourceUrl
    }

    public mutating func getSearchRule() -> SearchRule {
        if let ruleSearch {
            return ruleSearch
        }
        let newRule = SearchRule()
        self.ruleSearch = newRule
        return newRule
    }

    public mutating func getExploreRule() -> ExploreRule {
        if let ruleExplore {
            return ruleExplore
        }
        let newRule = ExploreRule()
        self.ruleExplore = newRule
        return newRule
    }

    public mutating func getBookInfoRule() -> BookInfoRule {
        if let ruleBookInfo {
            return ruleBookInfo
        }
        let newRule = BookInfoRule()
        self.ruleBookInfo = newRule
        return newRule
    }

    public mutating func getTocRule() -> TocRule {
        if let ruleToc {
            return ruleToc
        }
        let newRule = TocRule()
        self.ruleToc = newRule
        return newRule
    }

    public mutating func getContentRule() -> ContentRule {
        if let ruleContent {
            return ruleContent
        }
        let newRule = ContentRule()
        self.ruleContent = newRule
        return newRule
    }

    public func getDisPlayNameGroup() -> String {
        guard let group = bookSourceGroup, !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return bookSourceName
        }
        return "\(bookSourceName) (\(group))"
    }

    private enum CodingKeys: String, CodingKey {
        case bookSourceUrl
        case bookSourceName
        case bookSourceGroup
        case bookSourceType
        case bookUrlPattern
        case customOrder
        case enabled
        case enabledExplore
        case jsLib
        case enabledCookieJar
        case concurrentRate
        case header
        case loginUrl
        case loginUi
        case loginCheckJs
        case coverDecodeJs
        case bookSourceComment
        case variableComment
        case lastUpdateTime
        case respondTime
        case weight
        case exploreUrl
        case exploreScreen
        case ruleExplore
        case searchUrl
        case ruleSearch
        case ruleBookInfo
        case ruleToc
        case ruleContent
        case ruleReview
        case eventListener
        case customButton
        case homepageModules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bookSourceUrl = try container.decode(String.self, forKey: .bookSourceUrl)
        self.bookSourceName = try container.decode(String.self, forKey: .bookSourceName)
        self.bookSourceGroup = try container.decodeIfPresent(String.self, forKey: .bookSourceGroup)
        self.bookSourceType = container.decodeLenientInt(forKey: .bookSourceType)
        self.bookUrlPattern = try container.decodeIfPresent(String.self, forKey: .bookUrlPattern)
        self.customOrder = container.decodeLenientInt(forKey: .customOrder)
        self.enabled = container.decodeLenientBool(forKey: .enabled)
        self.enabledExplore = container.decodeLenientBool(forKey: .enabledExplore)
        self.jsLib = try container.decodeIfPresent(String.self, forKey: .jsLib)
        self.enabledCookieJar = container.decodeLenientBool(forKey: .enabledCookieJar)
        self.concurrentRate = try container.decodeIfPresent(String.self, forKey: .concurrentRate)
        self.header = try container.decodeIfPresent(String.self, forKey: .header)
        self.loginUrl = try container.decodeIfPresent(String.self, forKey: .loginUrl)
        self.loginUi = try container.decodeIfPresent(String.self, forKey: .loginUi)
        self.loginCheckJs = try container.decodeIfPresent(String.self, forKey: .loginCheckJs)
        self.coverDecodeJs = try container.decodeIfPresent(String.self, forKey: .coverDecodeJs)
        self.bookSourceComment = try container.decodeIfPresent(String.self, forKey: .bookSourceComment)
        self.variableComment = try container.decodeIfPresent(String.self, forKey: .variableComment)
        self.lastUpdateTime = container.decodeLenientInt64(forKey: .lastUpdateTime)
        self.respondTime = container.decodeLenientInt64(forKey: .respondTime)
        self.weight = container.decodeLenientInt(forKey: .weight)
        self.exploreUrl = try container.decodeIfPresent(String.self, forKey: .exploreUrl)
        self.exploreScreen = try container.decodeIfPresent(String.self, forKey: .exploreScreen)
        self.ruleExplore = try container.decodeIfPresent(ExploreRule.self, forKey: .ruleExplore)
        self.searchUrl = try container.decodeIfPresent(String.self, forKey: .searchUrl)
        self.ruleSearch = try container.decodeIfPresent(SearchRule.self, forKey: .ruleSearch)
        self.ruleBookInfo = try container.decodeIfPresent(BookInfoRule.self, forKey: .ruleBookInfo)
        self.ruleToc = try container.decodeIfPresent(TocRule.self, forKey: .ruleToc)
        self.ruleContent = try container.decodeIfPresent(ContentRule.self, forKey: .ruleContent)
        self.ruleReview = try container.decodeIfPresent(ReviewRule.self, forKey: .ruleReview)
        self.eventListener = container.decodeLenientBool(forKey: .eventListener)
        self.customButton = container.decodeLenientBool(forKey: .customButton)
        self.homepageModules = try container.decodeIfPresent(String.self, forKey: .homepageModules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookSourceUrl, forKey: .bookSourceUrl)
        try container.encode(bookSourceName, forKey: .bookSourceName)
        try container.encodeIfPresent(bookSourceGroup, forKey: .bookSourceGroup)
        try container.encodeIfPresent(bookSourceType, forKey: .bookSourceType)
        try container.encodeIfPresent(bookUrlPattern, forKey: .bookUrlPattern)
        try container.encodeIfPresent(customOrder, forKey: .customOrder)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(enabledExplore, forKey: .enabledExplore)
        try container.encodeIfPresent(jsLib, forKey: .jsLib)
        try container.encodeIfPresent(enabledCookieJar, forKey: .enabledCookieJar)
        try container.encodeIfPresent(concurrentRate, forKey: .concurrentRate)
        try container.encodeIfPresent(header, forKey: .header)
        try container.encodeIfPresent(loginUrl, forKey: .loginUrl)
        try container.encodeIfPresent(loginUi, forKey: .loginUi)
        try container.encodeIfPresent(loginCheckJs, forKey: .loginCheckJs)
        try container.encodeIfPresent(coverDecodeJs, forKey: .coverDecodeJs)
        try container.encodeIfPresent(bookSourceComment, forKey: .bookSourceComment)
        try container.encodeIfPresent(variableComment, forKey: .variableComment)
        try container.encodeIfPresent(lastUpdateTime, forKey: .lastUpdateTime)
        try container.encodeIfPresent(respondTime, forKey: .respondTime)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(exploreUrl, forKey: .exploreUrl)
        try container.encodeIfPresent(exploreScreen, forKey: .exploreScreen)
        try container.encodeIfPresent(ruleExplore, forKey: .ruleExplore)
        try container.encodeIfPresent(searchUrl, forKey: .searchUrl)
        try container.encodeIfPresent(ruleSearch, forKey: .ruleSearch)
        try container.encodeIfPresent(ruleBookInfo, forKey: .ruleBookInfo)
        try container.encodeIfPresent(ruleToc, forKey: .ruleToc)
        try container.encodeIfPresent(ruleContent, forKey: .ruleContent)
        try container.encodeIfPresent(ruleReview, forKey: .ruleReview)
        try container.encodeIfPresent(eventListener, forKey: .eventListener)
        try container.encodeIfPresent(customButton, forKey: .customButton)
        try container.encodeIfPresent(homepageModules, forKey: .homepageModules)
    }
}

private extension KeyedDecodingContainer {
    func decodeLenientInt(forKey key: Key) -> Int? {
        if let val = try? decodeIfPresent(Int.self, forKey: key) {
            return val
        }
        if let str = try? decodeIfPresent(String.self, forKey: key) {
            return Int(str)
        }
        return nil
    }

    func decodeLenientInt64(forKey key: Key) -> Int64? {
        if let val = try? decodeIfPresent(Int64.self, forKey: key) {
            return val
        }
        if let str = try? decodeIfPresent(String.self, forKey: key) {
            return Int64(str)
        }
        return nil
    }

    func decodeLenientBool(forKey key: Key) -> Bool? {
        if let val = try? decodeIfPresent(Bool.self, forKey: key) {
            return val
        }
        if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
            return intVal != 0
        }
        if let str = try? decodeIfPresent(String.self, forKey: key) {
            return str == "true" || str == "1"
        }
        return nil
    }
}
