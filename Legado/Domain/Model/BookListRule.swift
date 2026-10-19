import Foundation

/// 书籍列表提取规则协议 (对齐 Android Legado BookListRule.kt)
public protocol BookListRule {
    var bookList: String? { get set }
    var name: String? { get set }
    var author: String? { get set }
    var intro: String? { get set }
    var kind: String? { get set }
    var lastChapter: String? { get set }
    var updateTime: String? { get set }
    var bookUrl: String? { get set }
    var coverUrl: String? { get set }
    var wordCount: String? { get set }
}
