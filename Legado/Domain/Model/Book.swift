import Foundation

/// 书籍领域模型（纯业务实体，不依赖存储框架与 UI）
public struct Book: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        bookUrl
    }

    /// 书籍详情页完整 URL 或本地文件唯一路径
    public var bookUrl: String
    /// 目录页完整 URL
    public var tocUrl: String
    /// 书源 URL 或特殊标识 (如 local)
    public var origin: String
    /// 书源名称
    public var originName: String
    /// 书名
    public var name: String
    /// 作者
    public var author: String
    /// 分类标签 (以空格或逗号分隔)
    public var kind: String?
    /// 封面图片 URL
    public var coverUrl: String?
    /// 简介
    public var intro: String?
    /// 最新章节标题
    public var latestChapterTitle: String?
    /// 最新章节更新时间戳 (毫秒)
    public var latestChapterTime: Int64
    /// 当前阅读章节标题
    public var durChapterTitle: String?
    /// 当前阅读章节索引 (0-based)
    public var durChapterIndex: Int
    /// 当前阅读章节内字符偏移量
    public var durChapterPos: Int
    /// 最近阅读时间戳 (毫秒)
    public var durChapterTime: Int64
    /// 字数描述 (如 120万字)
    public var wordCount: String?
    /// 书架排序权重
    public var order: Int
    /// 总章节数
    public var totalChapterNum: Int
    /// 所属自定义分组名称
    public var groupName: String?
    /// 详情页抓取的原始 HTML
    public var infoHtml: String?
    /// 目录页抓取的原始 HTML
    public var tocHtml: String?
    /// 书籍类型 (0: 文本, 1: 音频, 2: 图片, 4: 视频)
    public var type: Int
    /// 列表提取的简介 (与详情页 intro 独立)
    public var listIntro: String?
    /// 用户自定义分类标签
    public var customTag: String?
    /// 用户自定义封面 URL
    public var customCoverUrl: String?
    /// 用户自定义简介
    public var customIntro: String?
    /// 备注
    public var remark: String?
    /// 自定义字符集名称 (本地书籍)
    public var charset: String?
    /// 单独标记为私密书籍
    public var isPrivate: Bool
    /// 刷新书架时更新书籍信息
    public var canUpdate: Bool
    /// 单独为本书关闭阅读记录
    public var disableReadRecord: Bool
    /// 书源排序
    public var originOrder: Int
    /// 最近一次检查新章节时间
    public var lastCheckTime: Int64
    /// 最近一次检查新章节数量
    public var lastCheckCount: Int
    /// 云同步时间
    public var syncTime: Int64
    /// 批量下载链接列表
    public var downloadUrls: [String]?
    /// 自定义书籍变量
    public var variable: String?
    /// 阅读配置 (对齐 Android ReadConfig)
    public var config: ReadConfig

    public init(
        bookUrl: String,
        tocUrl: String = "",
        origin: String = "local",
        originName: String = "",
        name: String,
        author: String,
        kind: String? = nil,
        coverUrl: String? = nil,
        intro: String? = nil,
        latestChapterTitle: String? = nil,
        latestChapterTime: Int64 = 0,
        durChapterTitle: String? = nil,
        durChapterIndex: Int = 0,
        durChapterPos: Int = 0,
        durChapterTime: Int64 = 0,
        wordCount: String? = nil,
        order: Int = 0,
        totalChapterNum: Int = 0,
        groupName: String? = nil,
        infoHtml: String? = nil,
        tocHtml: String? = nil,
        type: Int = 0,
        listIntro: String? = nil,
        customTag: String? = nil,
        customCoverUrl: String? = nil,
        customIntro: String? = nil,
        remark: String? = nil,
        charset: String? = nil,
        isPrivate: Bool = false,
        canUpdate: Bool = true,
        disableReadRecord: Bool = false,
        originOrder: Int = 0,
        lastCheckTime: Int64 = 0,
        lastCheckCount: Int = 0,
        syncTime: Int64 = 0,
        downloadUrls: [String]? = nil,
        variable: String? = nil,
        config: ReadConfig = ReadConfig()) {
        self.bookUrl = bookUrl
        self.tocUrl = tocUrl
        self.origin = origin
        self.originName = originName
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.intro = intro
        self.latestChapterTitle = latestChapterTitle
        self.latestChapterTime = latestChapterTime
        self.durChapterTitle = durChapterTitle
        self.durChapterIndex = durChapterIndex
        self.durChapterPos = durChapterPos
        self.durChapterTime = durChapterTime
        self.wordCount = wordCount
        self.order = order
        self.totalChapterNum = totalChapterNum
        self.groupName = groupName
        self.infoHtml = infoHtml
        self.tocHtml = tocHtml
        self.type = type
        self.listIntro = listIntro
        self.customTag = customTag
        self.customCoverUrl = customCoverUrl
        self.customIntro = customIntro
        self.remark = remark
        self.charset = charset
        self.isPrivate = isPrivate
        self.canUpdate = canUpdate
        self.disableReadRecord = disableReadRecord
        self.originOrder = originOrder
        self.lastCheckTime = lastCheckTime
        self.lastCheckCount = lastCheckCount
        self.syncTime = syncTime
        self.downloadUrls = downloadUrls
        self.variable = variable
        self.config = config
    }

    public var isAudio: Bool {
        (type & 1) != 0
    }

    public var isImage: Bool {
        (type & 2) != 0
    }

    public var isVideo: Bool {
        (type & 4) != 0
    }

    public var isLocal: Bool {
        origin == "local" || origin.hasPrefix("webdav")
    }

    public var isOnLineTxt: Bool {
        !isLocal && type == 0
    }

    public mutating func removeAllBookType() {
        type = 0
    }

    public mutating func addType(_ newType: Int) {
        type |= newType
    }
}

/// 书籍阅读配置 (对齐 Android Legado ReadConfig)
public struct ReadConfig: Codable, Hashable, Sendable {
    public var fixedType: Bool
    public init(fixedType: Bool = false) {
        self.fixedType = fixedType
    }
}
