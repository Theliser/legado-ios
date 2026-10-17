import Foundation

/// 获取所有有效书源的发现分类列表用例
public final class GetExploreCategoriesUseCase: Sendable {
    private let sourceRepository: BookSourceRepository
    private let exploreService: SourceExploreService

    public init(
        sourceRepository: BookSourceRepository,
        exploreService: SourceExploreService = .shared) {
        self.sourceRepository = sourceRepository
        self.exploreService = exploreService
    }

    public func execute() async throws -> [ExploreCategory] {
        let sources = try await sourceRepository.fetchEnabledSources()
        var allCategories: [ExploreCategory] = []

        for source in sources {
            let categories = exploreService.parseCategories(source: source)
            allCategories.append(contentsOf: categories)
        }

        return allCategories
    }
}
