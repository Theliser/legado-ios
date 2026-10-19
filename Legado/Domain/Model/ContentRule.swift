import Foundation

/// 正文页提取规则 (对齐 Android Legado ContentRule.kt)
public struct ContentRule: Codable, Equatable, Sendable {
    public var content: String?
    public var subContent: String?
    public var title: String?
    public var nextContentUrl: String?
    public var webJs: String?
    public var sourceRegex: String?
    public var replaceRegex: String?
    public var imageStyle: String?
    public var imageDecode: String?
    public var payAction: String?
    public var callBackJs: String?

    public init(
        content: String? = nil,
        subContent: String? = nil,
        title: String? = nil,
        nextContentUrl: String? = nil,
        webJs: String? = nil,
        sourceRegex: String? = nil,
        replaceRegex: String? = nil,
        imageStyle: String? = nil,
        imageDecode: String? = nil,
        payAction: String? = nil,
        callBackJs: String? = nil) {
        self.content = content
        self.subContent = subContent
        self.title = title
        self.nextContentUrl = nextContentUrl
        self.webJs = webJs
        self.sourceRegex = sourceRegex
        self.replaceRegex = replaceRegex
        self.imageStyle = imageStyle
        self.imageDecode = imageDecode
        self.payAction = payAction
        self.callBackJs = callBackJs
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case subContent
        case title
        case nextContentUrl
        case webJs
        case sourceRegex
        case replaceRegex
        case imageStyle
        case imageDecode
        case payAction
        case callBackJs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.subContent = try container.decodeIfPresent(String.self, forKey: .subContent)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.nextContentUrl = try container.decodeIfPresent(String.self, forKey: .nextContentUrl)
        self.sourceRegex = try container.decodeIfPresent(String.self, forKey: .sourceRegex)
            ?? container.decodeIfPresent(String.self, forKey: .replaceRegex)
        self.replaceRegex = try container.decodeIfPresent(String.self, forKey: .replaceRegex)
            ?? container.decodeIfPresent(String.self, forKey: .sourceRegex)
        self.webJs = try container.decodeIfPresent(String.self, forKey: .webJs)
        self.imageStyle = try container.decodeIfPresent(String.self, forKey: .imageStyle)
        self.imageDecode = try container.decodeIfPresent(String.self, forKey: .imageDecode)
        self.payAction = try container.decodeIfPresent(String.self, forKey: .payAction)
        self.callBackJs = try container.decodeIfPresent(String.self, forKey: .callBackJs)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(subContent, forKey: .subContent)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(nextContentUrl, forKey: .nextContentUrl)
        try container.encodeIfPresent(sourceRegex, forKey: .sourceRegex)
        try container.encodeIfPresent(replaceRegex, forKey: .replaceRegex)
        try container.encodeIfPresent(webJs, forKey: .webJs)
        try container.encodeIfPresent(imageStyle, forKey: .imageStyle)
        try container.encodeIfPresent(imageDecode, forKey: .imageDecode)
        try container.encodeIfPresent(payAction, forKey: .payAction)
        try container.encodeIfPresent(callBackJs, forKey: .callBackJs)
    }
}

public typealias RuleContent = ContentRule
