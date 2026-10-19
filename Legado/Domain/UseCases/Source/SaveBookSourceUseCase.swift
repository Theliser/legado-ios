import Foundation

/// 书源编辑与保存异常
public enum BookSourceEditError: LocalizedError, Sendable {
    case emptyName
    case emptyUrl
    case invalidUrl
    case invalidJson(String)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "书源名称不能为空"

        case .emptyUrl:
            return "书源 URL 不能为空"

        case .invalidUrl:
            return "书源 URL 格式无效"

        case let .invalidJson(msg):
            return "书源 JSON 解析失败: \(msg)"
        }
    }
}

/// 保存或更新书源用例（纯业务逻辑，不依赖 SwiftUI/UIKit）
public final class SaveBookSourceUseCase: Sendable {
    private let sourceRepository: BookSourceRepository

    public init(sourceRepository: BookSourceRepository) {
        self.sourceRepository = sourceRepository
    }

    public func execute(source: BookSource, originalUrl: String? = nil) async throws {
        let trimmedName = source.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw BookSourceEditError.emptyName
        }

        let trimmedUrl = source.bookSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else {
            throw BookSourceEditError.emptyUrl
        }

        var sourceToSave = source
        sourceToSave.bookSourceName = trimmedName
        sourceToSave.bookSourceUrl = trimmedUrl
        sourceToSave.lastUpdateTime = Int64(Date().timeIntervalSince1970 * 1000)

        // 如果旧 URL 存在且发生了更改，先清理旧 URL 记录，防止遗留重复废弃记录
        if let originalUrl, !originalUrl.isEmpty, originalUrl != trimmedUrl {
            try await sourceRepository.deleteSource(url: originalUrl)
        }

        try await sourceRepository.updateSource(sourceToSave)
    }
}
