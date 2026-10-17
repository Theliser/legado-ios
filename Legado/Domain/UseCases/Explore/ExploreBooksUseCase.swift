import Foundation

/// 根据选定分类与页码获取发现书籍列表用例
public final class ExploreBooksUseCase: Sendable {
    private let sourceRepository: BookSourceRepository
    private let exploreService: SourceExploreService

    public init(
        sourceRepository: BookSourceRepository,
        exploreService: SourceExploreService = .shared) {
        self.sourceRepository = sourceRepository
        self.exploreService = exploreService
    }

    public func execute(category: ExploreCategory, page: Int = 1) async throws -> [Book] {
        let sources = try await sourceRepository.fetchSources()
        guard let source = sources.first(where: { $0.bookSourceUrl == category.sourceUrl }) else {
            throw URLError(.resourceUnavailable)
        }

        return try await exploreService.fetchExploreBooks(source: source, category: category, page: page)
    }
}
