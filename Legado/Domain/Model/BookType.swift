import Foundation

/// 书籍类型掩码常量 (100% 对齐 Android Legado io.legado.app.constant.BookType)
public enum BookType {
    /// 4 视频
    public static let video = 0b100
    /// 8 文本
    public static let text = 0b1000
    /// 16 更新失败
    public static let updateError = 0b10000
    /// 32 音频
    public static let audio = 0b100000
    /// 64 图片
    public static let image = 0b1000000
    /// 128 只提供下载服务的网站
    public static let webFile = 0b1000_0000
    /// 256 本地书籍
    public static let local = 0b1_0000_0000
    /// 512 压缩包 (书籍文件从压缩包内解压)
    public static let archive = 0b10_0000_0000
    /// 1024 未正式加入到书架的临时阅读书籍
    public static let notShelf = 0b100_0000_0000

    /// 所有可以从书源转换的书籍类型
    public static let allBookType = text | image | audio | webFile
    /// 所有书籍类型包含本地
    public static let allBookTypeLocal = text | image | audio | webFile | local

    /// 本地书籍书源标志
    public static let localTag = "loc_book"
    /// WebDAV 书籍标志
    public static let webDavTag = "webDav::"
}

/// 书源类型常量 (100% 对齐 Android Legado io.legado.app.constant.BookSourceType)
public enum BookSourceType {
    /// 0 文本
    public static let `default` = 0
    /// 1 音频
    public static let audio = 1
    /// 2 图片
    public static let image = 2
    /// 3 只提供下载服务的网站
    public static let file = 3
}

public extension BookSource {
    /// 根据书源类型获取书籍类型位掩码 (对齐 Android BookSourceExtensions.kt:128)
    func getBookType() -> Int {
        switch bookSourceType {
        case BookSourceType.file:
            return BookType.text | BookType.webFile

        case BookSourceType.image:
            return BookType.image

        case BookSourceType.audio:
            return BookType.audio

        default:
            return BookType.text
        }
    }
}
