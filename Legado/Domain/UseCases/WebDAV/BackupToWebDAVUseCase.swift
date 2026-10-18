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

    /// 生成备份数据包 Bundle
    public func generateBackupBundle() async throws -> WebDAVBackupBundle {
        let books = try await bookRepository.getBookshelf()
        let sources = try await sourceRepository.fetchSources()

        return WebDAVBackupBundle(
            version: 1,
            backupTime: Date(),
            appVersion: "1.0",
            books: books,
            sources: sources,
            replaceRules: PurifyContentUseCase.defaultRules)
    }

    /// 导出为 JSON 数据
    public func exportBackupJsonData(bundle: WebDAVBackupBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    /// 执行云端备份
    public func execute(config: WebDAVConfig) async throws -> WebDAVBackupSummary {
        let bundle = try await generateBackupBundle()
        let data = try exportBackupJsonData(bundle: bundle)

        try await webDAVClient.upload(
            data: data,
            filename: "legado_backup.json",
            config: config)

        return WebDAVBackupSummary(
            bookCount: bundle.books.count,
            sourceCount: bundle.sources.count,
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
