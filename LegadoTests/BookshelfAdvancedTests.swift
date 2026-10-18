import Foundation
@testable import Legado
import Testing

@Suite("Bookshelf Advanced MVI and Grouping Suite")
struct BookshelfAdvancedTests {
    @Test("Test BookGroup Model Properties")
    func bookGroupModel() {
        let group = BookGroup(id: "grp-1", name: "玄幻修真", order: 2)
        #expect(group.id == "grp-1")
        #expect(group.name == "玄幻修真")
        #expect(group.order == 2)
    }

    @Test("Test BookGroupRepositoryImpl SwiftData CRUD")
    func bookGroupRepositoryCRUD() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let repository = BookGroupRepositoryImpl(modelContainer: provider.container)

        let g1 = BookGroup(id: "g1", name: "科幻未来", order: 1)
        let g2 = BookGroup(id: "g2", name: "奇幻史诗", order: 0)

        try await repository.saveGroup(g1)
        try await repository.saveGroup(g2)

        let groups = try await repository.getGroups()
        #expect(groups.count == 2)
        #expect(groups[0].name == "奇幻史诗") // order 0 comes first
        #expect(groups[1].name == "科幻未来") // order 1 comes second

        try await repository.deleteGroup(id: "g1")
        let afterDelete = try await repository.getGroups()
        #expect(afterDelete.count == 1)
        #expect(afterDelete[0].id == "g2")
    }

    @Test("Test BookshelfState Computed Filtered Books")
    func bookshelfStateFiltering() {
        let b1 = Book(bookUrl: "https://a.com", name: "在读书籍", author: "作者A", durChapterIndex: 5, groupName: "玄幻")
        let b2 = Book(bookUrl: "https://b.com", name: "未读书籍", author: "作者B", durChapterIndex: 0, groupName: "科幻")
        let b3 = Book(bookUrl: "https://c.com", name: "完结书籍", author: "作者C", kind: "完结, 都市", durChapterIndex: 20)

        var state = BookshelfState(books: [b1, b2, b3])

        // 1. 全部
        state.selectedGroup = "全部"
        #expect(state.filteredBooks.count == 3)

        // 2. 在读 (b1 与 b3 均已开始阅读)
        state.selectedGroup = "在读"
        #expect(state.filteredBooks.count == 2)
        #expect(state.filteredBooks.map(\.name).contains("在读书籍"))
        #expect(state.filteredBooks.map(\.name).contains("完结书籍"))

        // 3. 未读
        state.selectedGroup = "未读"
        #expect(state.filteredBooks.count == 1)
        #expect(state.filteredBooks.first?.name == "未读书籍")

        // 4. 完结
        state.selectedGroup = "完结"
        #expect(state.filteredBooks.count == 1)
        #expect(state.filteredBooks.first?.name == "完结书籍")

        // 5. 自定义分组
        state.selectedGroup = "玄幻"
        #expect(state.filteredBooks.count == 1)
        #expect(state.filteredBooks.first?.name == "在读书籍")

        // 6. 搜索词组合过滤
        state.selectedGroup = "全部"
        state.searchText = "作者B"
        #expect(state.filteredBooks.count == 1)
        #expect(state.filteredBooks.first?.name == "未读书籍")
    }

    @Test("Test BookshelfViewModel Batch & Layout Actions")
    @MainActor
    func bookshelfViewModelActions() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let groupRepo = BookGroupRepositoryImpl(modelContainer: provider.container)

        let book1 = Book(bookUrl: "https://example.com/b1", name: "诡秘之主", author: "爱潜水的乌贼")
        let book2 = Book(bookUrl: "https://example.com/b2", name: "宿命之环", author: "爱潜水的乌贼")
        try await bookRepo.saveBook(book1)
        try await bookRepo.saveBook(book2)

        let vm = BookshelfViewModel(
            getBookshelfUseCase: GetBookshelfUseCase(bookRepository: bookRepo),
            removeBookFromShelfUseCase: RemoveBookFromShelfUseCase(bookRepository: bookRepo),
            checkBookUpdatesUseCase: CheckBookUpdatesUseCase(
                bookRepository: bookRepo,
                sourceRepository: BookSourceRepositoryImpl(modelContainer: provider.container)),
            saveBookToShelfUseCase: SaveBookToShelfUseCase(bookRepository: bookRepo),
            getBookGroupsUseCase: GetBookGroupsUseCase(groupRepository: groupRepo),
            saveBookGroupUseCase: SaveBookGroupUseCase(groupRepository: groupRepo),
            deleteBookGroupUseCase: DeleteBookGroupUseCase(groupRepository: groupRepo))

        // 等待数据加载
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(vm.state.books.count == 2)

        // 1. 切换布局模式
        #expect(vm.state.layoutMode == BookshelfLayoutMode.grid)
        vm.send(.toggleLayoutMode)
        #expect(vm.state.layoutMode == BookshelfLayoutMode.list)

        // 2. 批量模式操作
        #expect(!vm.state.isBatchMode)
        vm.send(.toggleBatchMode)
        #expect(vm.state.isBatchMode)

        // 全选
        vm.send(.selectAll)
        #expect(vm.state.selectedBookUrls.count == 2)

        // 反选/取消全选
        vm.send(.deselectAll)
        #expect(vm.state.selectedBookUrls.isEmpty)

        // 单选书籍
        vm.send(.toggleSelectBook(bookUrl: book1.bookUrl))
        #expect(vm.state.selectedBookUrls.contains(book1.bookUrl))

        // 批量移动分组
        vm.send(.batchMoveSelectedToGroup(groupName: "爱潜水的乌贼专区"))
        try await Task.sleep(nanoseconds: 100_000_000)

        let updatedBook1 = try await bookRepo.getBook(by: book1.bookUrl)
        #expect(updatedBook1?.groupName == "爱潜水的乌贼专区")
        #expect(!vm.state.isBatchMode) // 移动后退出批量模式
    }
}
