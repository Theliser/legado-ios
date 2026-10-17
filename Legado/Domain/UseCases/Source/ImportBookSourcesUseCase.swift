import Foundation

/// 导入书源用例 (支持 URL 与 JSON 文本)
public final class ImportBookSourcesUseCase: Sendable {
    private let sourceRepository: BookSourceRepository
    private let parser: ParseBookSourceUseCase

    public init(
        sourceRepository: BookSourceRepository,
        parser: ParseBookSourceUseCase = ParseBookSourceUseCase()) {
        self.sourceRepository = sourceRepository
        self.parser = parser
    }

    /// 执行书源导入并写入数据库，返回成功导入的书源数量
    public func execute(input: String) async throws -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BookSourceParseError.invalidData
        }

        let sources: [BookSource]
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            sources = try await parser.importFromUrl(urlString: trimmed)
        } else {
            sources = try parser.parse(json: trimmed)
        }

        guard !sources.isEmpty else {
            return 0
        }

        try await sourceRepository.saveSources(sources)
        return sources.count
    }
}
