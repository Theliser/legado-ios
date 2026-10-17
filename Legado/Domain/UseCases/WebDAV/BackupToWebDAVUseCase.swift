import Foundation

/// 备份至 WebDAV 云端存储用例
public final class BackupToWebDAVUseCase: Sendable {
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

    /// 执行云端备份
    public func execute(config: WebDAVConfig) async throws -> WebDAVBackupSummary {
        let books = try await bookRepository.getBookshelf()
        let sources = try await sourceRepository.fetchSources()

        let bundle = WebDAVBackupBundle(
            version: 1,
            backupTime: Date(),
            appVersion: "1.0",
            books: books,
            sources: sources,
            replaceRules: PurifyContentUseCase.defaultRules)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        try await webDAVClient.upload(
            data: data,
            filename: "legado_backup.json",
            config: config)

        return WebDAVBackupSummary(
            bookCount: books.count,
            sourceCount: sources.count,
            dataSizeBytes: data.count,
            backupDate: bundle.backupTime)
    }
}

/// 备份摘要信息
public struct WebDAVBackupSummary: Sendable, Equatable {
    public let bookCount: Int
    public let sourceCount: Int
    public let dataSizeBytes: Int
    public let backupDate: Date

    public init(
        bookCount: Int,
        sourceCount: Int,
        dataSizeBytes: Int,
        backupDate: Date) {
        self.bookCount = bookCount
        self.sourceCount = sourceCount
        self.dataSizeBytes = dataSizeBytes
        self.backupDate = backupDate
    }
}
