import Foundation

/// 切换书源启用状态用例
public final class ToggleBookSourceEnabledUseCase: Sendable {
    private let sourceRepository: BookSourceRepository

    public init(sourceRepository: BookSourceRepository) {
        self.sourceRepository = sourceRepository
    }

    public func execute(sourceUrl: String, enabled: Bool) async throws {
        let sources = try await sourceRepository.fetchSources()
        guard var target = sources.first(where: { $0.bookSourceUrl == sourceUrl }) else {
            return
        }

        target.enabled = enabled
        try await sourceRepository.updateSource(target)
    }
}
