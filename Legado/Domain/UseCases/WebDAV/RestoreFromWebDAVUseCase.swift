import Foundation

/// 从 WebDAV 云端还原数据用例
public final class RestoreFromWebDAVUseCase: Sendable {
    private let bookRepository: BookRepository
    private let sourceRepository: BookSourceRepository
    private let webDAVClient: WebDAVClient

    public init(
        bookRepository: BookRepository,
        sourceRepository: BookSourceRepository,
        webDAVClient: WebDAVClient = .shared) {
        self.bookRepository = bookRepository
        self.sourceRepository = sourceRepository
        self.webDAVClient = webDAVClient
    }

    /// 执行云端还原
    public func execute(config: WebDAVConfig) async throws -> WebDAVBackupSummary {
        let data = try await webDAVClient.download(
            filename: "legado_backup.json",
            config: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(WebDAVBackupBundle.self, from: data)

        // 还原书源
        if !bundle.sources.isEmpty {
            try await sourceRepository.saveSources(bundle.sources)
        }

        // 还原书架
        for book in bundle.books {
            try await bookRepository.saveBook(book)
        }

        return WebDAVBackupSummary(
            bookCount: bundle.books.count,
            sourceCount: bundle.sources.count,
            dataSizeBytes: data.count,
            backupDate: bundle.backupTime)
    }
}
