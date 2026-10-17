import Foundation

/// 删除书源用例
public final class DeleteBookSourceUseCase: Sendable {
    private let sourceRepository: BookSourceRepository

    public init(sourceRepository: BookSourceRepository) {
        self.sourceRepository = sourceRepository
    }

    public func execute(sourceUrl: String) async throws {
        try await sourceRepository.deleteSource(url: sourceUrl)
    }
}
