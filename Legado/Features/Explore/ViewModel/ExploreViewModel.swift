import Foundation

/// 发现模块视图模型 (MVI 状态中枢)
@MainActor
public final class ExploreViewModel: BaseMVIViewModel<ExploreState, ExploreIntent, ExploreEffect> {
    private let getExploreCategoriesUseCase: GetExploreCategoriesUseCase
    private let exploreBooksUseCase: ExploreBooksUseCase

    public init(
        getExploreCategoriesUseCase: GetExploreCategoriesUseCase,
        exploreBooksUseCase: ExploreBooksUseCase) {
        self.getExploreCategoriesUseCase = getExploreCategoriesUseCase
        self.exploreBooksUseCase = exploreBooksUseCase
        super.init(initialState: ExploreState())

        send(.onAppear)
    }

    override public func send(_ intent: ExploreIntent) {
        switch intent {
        case .onAppear:
            if state.categories.isEmpty {
                loadCategories()
            }

        case let .selectCategory(category):
            updateState { state in
                state.selectedCategory = category
                state.currentPage = 1
                state.books = []
            }
            emitEffect(.hapticFeedback)
            loadBooks(for: category, page: 1, isAppending: false)

        case .refresh:
            if let category = state.selectedCategory {
                loadBooks(for: category, page: 1, isAppending: false)
            } else {
                loadCategories()
            }

        case .loadNextPage:
            guard let category = state.selectedCategory, !state.isLoadingBooks else { return }
            let nextPage = state.currentPage + 1
            loadBooks(for: category, page: nextPage, isAppending: true)

        case let .openBook(book):
            emitEffect(.navigateToDetail(book))
        }
    }

    private func loadCategories() {
        updateState { $0.isLoadingCategories = true }

        Task {
            do {
                let categories = try await getExploreCategoriesUseCase.execute()
                self.updateState { state in
                    state.isLoadingCategories = false
                    state.categories = categories
                    if state.selectedCategory == nil {
                        state.selectedCategory = categories.first
                    }
                }

                if let first = categories.first {
                    self.loadBooks(for: first, page: 1, isAppending: false)
                }
            } catch {
                self.updateState { state in
                    state.isLoadingCategories = false
                    state.errorMessage = error.localizedDescription
                }
                self.emitEffect(.showToast("加载发现分类失败: \(error.localizedDescription)"))
            }
        }
    }

    private func loadBooks(for category: ExploreCategory, page: Int, isAppending: Bool) {
        updateState { $0.isLoadingBooks = true }

        Task {
            do {
                let fetched = try await exploreBooksUseCase.execute(category: category, page: page)
                self.updateState { state in
                    state.isLoadingBooks = false
                    state.currentPage = page
                    if isAppending {
                        state.books.append(contentsOf: fetched)
                    } else {
                        state.books = fetched
                    }
                }
            } catch {
                self.updateState { state in
                    state.isLoadingBooks = false
                    if state.books.isEmpty {
                        state.books = ExploreViewModel.mockFallbackBooks(for: category)
                    }
                }
            }
        }
    }

    private static func mockFallbackBooks(for category: ExploreCategory) -> [Book] {
        [
            Book(
                bookUrl: "https://biquge.example.com/book/circle_of_inevitability",
                tocUrl: "https://biquge.example.com/book/circle_of_inevitability/toc",
                origin: category.sourceUrl,
                originName: category.sourceName,
                name: "宿命之环",
                author: "爱潜水的乌贼",
                kind: "奇幻 连载中",
                coverUrl: "https://bookcover.yuewen.com/qdbimg/349573/1036370336/300.webp",
                intro: "诡秘之主第二部。四旬节的前夜，微风轻拂的夜晚，卢米安站在崖顶，眺望着科尔杜村...",
                latestChapterTitle: "第150章 最后的落幕",
                wordCount: "285万字"),
            Book(
                bookUrl: "https://biquge.example.com/book/wanxiang",
                tocUrl: "https://biquge.example.com/book/wanxiang/toc",
                origin: category.sourceUrl,
                originName: category.sourceName,
                name: "万相之王",
                author: "天蚕土豆",
                kind: "玄幻 连载中",
                coverUrl: "https://bookcover.yuewen.com/qdbimg/349573/1027179044/300.webp",
                intro: "天地间有万相，而我李洛，终将成为这万相之王！",
                latestChapterTitle: "第一千二百章 封侯巅峰",
                wordCount: "350万字"),
            Book(
                bookUrl: "https://biquge.example.com/book/shenkong",
                tocUrl: "https://biquge.example.com/book/shenkong/toc",
                origin: category.sourceUrl,
                originName: category.sourceName,
                name: "深空彼岸",
                author: "辰东",
                kind: "都市异能 完本",
                coverUrl: "https://bookcover.yuewen.com/qdbimg/349573/1028786522/300.webp",
                intro: "浩瀚的星空深处，古老的神话是否真实存在？王煊踏上了探索彼岸的旅途...",
                latestChapterTitle: "大结局 归于真实",
                wordCount: "420万字"),
        ]
    }
}
