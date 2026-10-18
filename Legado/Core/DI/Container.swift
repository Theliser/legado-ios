import Factory
import Foundation

// MARK: - Legado 全局依赖注入容器 (Factory 架构)

public extension Container {

    // MARK: - 基础底层设施与持久化

    /// SwiftData 模型容器提供者
    var modelContainerProvider: Factory<ModelContainerProvider> {
        self { @MainActor in ModelContainerProvider() }.singleton
    }

    /// 统一异步 HTTP 网络客户端
    var httpClient: Factory<HTTPClientProtocol> {
        self { HTTPClient.shared }.singleton
    }

    // MARK: - 数据仓库层 (Repository)

    /// 书源持久化仓库
    var bookSourceRepository: Factory<BookSourceRepository> {
        self { @MainActor in
            BookSourceRepositoryImpl(modelContainer: self.modelContainerProvider().container)
        }.shared
    }

    /// 书架与阅读进度持久化仓库
    var bookRepository: Factory<BookRepository> {
        self { @MainActor in
            BookRepositoryImpl(modelContainer: self.modelContainerProvider().container)
        }.shared
    }

    // MARK: - 引擎与核心解析服务

    /// 书源搜索执行服务
    var sourceSearchService: Factory<SourceSearchService> {
        self { SourceSearchService(httpClient: self.httpClient()) }.shared
    }

    /// 书源发现与分类抓取引擎
    var sourceExploreService: Factory<SourceExploreService> {
        self { SourceExploreService(httpClient: self.httpClient()) }.shared
    }

    /// 详情页与目录 (TOC) 解析引擎
    var sourceDetailAndTocService: Factory<SourceDetailAndTocService> {
        self { SourceDetailAndTocService(httpClient: self.httpClient()) }.shared
    }

    /// 章节正文解析引擎
    var contentParser: Factory<ContentParser> {
        self { ContentParser(httpClient: self.httpClient()) }.shared
    }

    /// 语音朗读 TTS 播放引擎
    var ttsPlayer: Factory<TTSPlayer> {
        self { @MainActor in TTSPlayer.shared }.singleton
    }

    // MARK: - 业务用例 (UseCases)

    /// 多书源并发搜索聚合用例
    var searchBooksUseCase: Factory<SearchBooksUseCase> {
        self { @MainActor in
            SearchBooksUseCase(
                sourceRepository: self.bookSourceRepository(),
                searchService: self.sourceSearchService())
        }.shared
    }

    /// 书籍加架用例
    var saveBookToShelfUseCase: Factory<SaveBookToShelfUseCase> {
        self { @MainActor in
            SaveBookToShelfUseCase(bookRepository: self.bookRepository())
        }.shared
    }

    /// 获取书架书籍列表用例
    var getBookshelfUseCase: Factory<GetBookshelfUseCase> {
        self { @MainActor in
            GetBookshelfUseCase(bookRepository: self.bookRepository())
        }.shared
    }

    /// 移出书架用例
    var removeBookFromShelfUseCase: Factory<RemoveBookFromShelfUseCase> {
        self { @MainActor in
            RemoveBookFromShelfUseCase(bookRepository: self.bookRepository())
        }.shared
    }

    /// 获取书籍详情用例
    var getBookDetailUseCase: Factory<GetBookDetailUseCase> {
        self { @MainActor in
            GetBookDetailUseCase(
                sourceRepository: self.bookSourceRepository(),
                bookRepository: self.bookRepository(),
                service: self.sourceDetailAndTocService())
        }.shared
    }

    /// 获取书籍目录用例
    var getBookTocUseCase: Factory<GetBookTocUseCase> {
        self { @MainActor in
            GetBookTocUseCase(
                sourceRepository: self.bookSourceRepository(),
                bookRepository: self.bookRepository(),
                service: self.sourceDetailAndTocService())
        }.shared
    }

    /// 检查书架书籍更新用例
    var checkBookUpdatesUseCase: Factory<CheckBookUpdatesUseCase> {
        self { @MainActor in
            CheckBookUpdatesUseCase(
                bookRepository: self.bookRepository(),
                sourceRepository: self.bookSourceRepository(),
                service: self.sourceDetailAndTocService())
        }.shared
    }

    /// 章节正文获取与三级缓存用例
    var getChapterContentUseCase: Factory<GetChapterContentUseCase> {
        self { @MainActor in
            GetChapterContentUseCase(
                sourceRepository: self.bookSourceRepository(),
                contentParser: self.contentParser())
        }.shared
    }

    /// 获取发现分类列表用例
    var getExploreCategoriesUseCase: Factory<GetExploreCategoriesUseCase> {
        self { @MainActor in
            GetExploreCategoriesUseCase(
                sourceRepository: self.bookSourceRepository(),
                exploreService: self.sourceExploreService())
        }.shared
    }

    /// 发现模块书籍抓取用例
    var exploreBooksUseCase: Factory<ExploreBooksUseCase> {
        self { @MainActor in
            ExploreBooksUseCase(
                sourceRepository: self.bookSourceRepository(),
                exploreService: self.sourceExploreService())
        }.shared
    }

    /// 启停书源用例
    var toggleBookSourceEnabledUseCase: Factory<ToggleBookSourceEnabledUseCase> {
        self { @MainActor in
            ToggleBookSourceEnabledUseCase(sourceRepository: self.bookSourceRepository())
        }.shared
    }

    /// 删除书源用例
    var deleteBookSourceUseCase: Factory<DeleteBookSourceUseCase> {
        self { @MainActor in
            DeleteBookSourceUseCase(sourceRepository: self.bookSourceRepository())
        }.shared
    }

    /// 导入书源用例
    var importBookSourcesUseCase: Factory<ImportBookSourcesUseCase> {
        self { @MainActor in
            ImportBookSourcesUseCase(sourceRepository: self.bookSourceRepository())
        }.shared
    }

    /// 实时调试书源用例
    var debugBookSourceUseCase: Factory<DebugBookSourceUseCase> {
        self {
            DebugBookSourceUseCase(
                searchService: self.sourceSearchService(),
                detailAndTocService: self.sourceDetailAndTocService(),
                contentParser: self.contentParser())
        }.shared
    }

    /// 净化正文与广告替换用例
    var purifyContentUseCase: Factory<PurifyContentUseCase> {
        self { PurifyContentUseCase() }.shared
    }

    /// WebDAV 云端备份用例
    var backupToWebDAVUseCase: Factory<BackupToWebDAVUseCase> {
        self { @MainActor in
            BackupToWebDAVUseCase(
                bookRepository: self.bookRepository(),
                sourceRepository: self.bookSourceRepository())
        }.shared
    }

    /// WebDAV 云端恢复用例
    var restoreFromWebDAVUseCase: Factory<RestoreFromWebDAVUseCase> {
        self { @MainActor in
            RestoreFromWebDAVUseCase(
                bookRepository: self.bookRepository(),
                sourceRepository: self.bookSourceRepository())
        }.shared
    }
}
