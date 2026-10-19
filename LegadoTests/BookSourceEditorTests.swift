import Foundation
@testable import Legado
import Testing

@Suite("Book Source Editor and Live Studio Suite")
struct BookSourceEditorTests {

    // MARK: - UseCase 单元测试

    @Test("Test SaveBookSourceUseCase Validations")
    func useCaseValidations() async {
        let repo = BookSourceRepositoryImpl(modelContainer: ModelContainerProvider(inMemory: true).container)
        let useCase = SaveBookSourceUseCase(sourceRepository: repo)

        // 1. 书名为空
        let emptyNameSource = BookSource(bookSourceUrl: "https://a.com", bookSourceName: "")
        do {
            try await useCase.execute(source: emptyNameSource)
            Issue.record("Should have thrown emptyName error")
        } catch let error as BookSourceEditError {
            #expect(error.errorDescription == "书源名称不能为空")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // 2. URL 为空
        let emptyUrlSource = BookSource(bookSourceUrl: "   ", bookSourceName: "测试书源")
        do {
            try await useCase.execute(source: emptyUrlSource)
            Issue.record("Should have thrown emptyUrl error")
        } catch let error as BookSourceEditError {
            #expect(error.errorDescription == "书源 URL 不能为空")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Test SaveBookSourceUseCase Create, Update and Rename")
    func useCaseCreateAndUpdate() async throws {
        let repo = BookSourceRepositoryImpl(modelContainer: ModelContainerProvider(inMemory: true).container)
        let useCase = SaveBookSourceUseCase(sourceRepository: repo)

        // 1. 新建保存
        let original = BookSource(
            bookSourceUrl: "https://source1.example.com",
            bookSourceName: "示例书源1",
            bookSourceGroup: "网络")
        try await useCase.execute(source: original)

        var list = try await repo.fetchSources()
        #expect(list.count == 1)
        #expect(list.first?.bookSourceName == "示例书源1")

        // 2. 更新内容（不更改 URL）
        var updated = original
        updated.bookSourceName = "示例书源1(改)"
        try await useCase.execute(source: updated, originalUrl: original.bookSourceUrl)

        list = try await repo.fetchSources()
        #expect(list.count == 1)
        #expect(list.first?.bookSourceName == "示例书源1(改)")

        // 3. 更改主键 URL（重命名 URL）
        var renamed = updated
        renamed.bookSourceUrl = "https://source2.example.com"
        try await useCase.execute(source: renamed, originalUrl: original.bookSourceUrl)

        list = try await repo.fetchSources()
        #expect(list.count == 1)
        #expect(list.first?.bookSourceUrl == "https://source2.example.com")
    }

    // MARK: - ViewModel MVI 状态与交互测试

    @Test("Test BookSourceEditViewModel Initial State")
    @MainActor
    func viewModelInitialState() {
        // 1. 空白新建
        let newVm = BookSourceEditViewModel(source: nil)
        #expect(newVm.state.isNewSource == true)
        #expect(newVm.state.isDirty == false)
        #expect(newVm.state.canSave == false) // 名称和 URL 尚为空
        #expect(newVm.state.selectedTab == .base)
        #expect(newVm.state.isJsonEditorPresented == false)

        // 2. 加载已有书源
        let existingSource = BookSource(
            bookSourceUrl: "https://biquge.com",
            bookSourceName: "笔趣阁",
            bookSourceGroup: "常用",
            searchUrl: "/search?key={{key}}")
        let editVm = BookSourceEditViewModel(source: existingSource)
        #expect(editVm.state.isNewSource == false)
        #expect(editVm.state.isDirty == false)
        #expect(editVm.state.canSave == true)
        #expect(editVm.state.fieldValue(for: "bookSourceName") == "笔趣阁")
        #expect(editVm.state.fieldValue(for: "searchUrl") == "/search?key={{key}}")
    }

    @Test("Test BookSourceEditViewModel Field Updates and Dirty Tracking")
    @MainActor
    func viewModelFieldUpdates() {
        let vm = BookSourceEditViewModel(source: nil)

        // 更新基本信息
        vm.send(.updateField(key: "bookSourceName", value: "顶点小说"))
        vm.send(.updateField(key: "bookSourceUrl", value: "https://dingdian.com"))
        vm.send(.updateField(key: "bookSourceGroup", value: "精品"))

        #expect(vm.state.isDirty == true)
        #expect(vm.state.canSave == true)
        #expect(vm.state.source.bookSourceName == "顶点小说")
        #expect(vm.state.source.bookSourceUrl == "https://dingdian.com")
        #expect(vm.state.source.bookSourceGroup == "精品")

        // 切换标签与更新二级规则字段
        vm.send(.selectTab(.search))
        #expect(vm.state.selectedTab == .search)

        vm.send(.updateField(key: "searchUrl", value: "/s?wd={{key}}"))
        vm.send(.updateField(key: "ruleSearch.name", value: "tag.h2@text"))
        vm.send(.updateField(key: "ruleSearch.author", value: "class.author@text"))

        #expect(vm.state.fieldValue(for: "searchUrl") == "/s?wd={{key}}")
        #expect(vm.state.fieldValue(for: "ruleSearch.name") == "tag.h2@text")
        #expect(vm.state.fieldValue(for: "ruleSearch.author") == "class.author@text")

        // 更新布尔开关与源类型
        vm.send(.toggleBoolean(key: "enabledExplore", value: false))
        #expect(vm.state.source.enabledExplore == false)

        vm.send(.updateSourceType(1))
        #expect(vm.state.source.bookSourceType == 1)
    }

    @Test("Test BookSourceEditViewModel Syntax Chip Insertion")
    @MainActor
    func viewModelSyntaxChipInsertion() {
        let vm = BookSourceEditViewModel(source: nil)

        // 设定当前焦点输入框
        vm.send(.setActiveField(key: "ruleContent.content"))
        #expect(vm.state.activeFieldKey == "ruleContent.content")

        // 插入语法标记
        vm.send(.insertSyntaxChip(token: "id.content"))
        #expect(vm.state.fieldValue(for: "ruleContent.content") == "id.content")

        // 级联追加标记
        vm.send(.insertSyntaxChip(token: "@textNodes"))
        #expect(vm.state.fieldValue(for: "ruleContent.content") == "id.content@textNodes")
        #expect(vm.state.isDirty == true)
    }

    @Test("Test BookSourceEditViewModel JSON Mode and Parsing")
    @MainActor
    func viewModelJsonMode() {
        let original = BookSource(
            bookSourceUrl: "https://test.com",
            bookSourceName: "测试源")
        let vm = BookSourceEditViewModel(source: original)

        // 切换至源码模式
        vm.send(.toggleJsonMode)
        #expect(vm.state.isJsonEditorPresented == true)
        #expect(vm.state.rawJsonText.contains("https://test.com"))

        // 编辑 JSON 文本
        let editedJson = """
        {
          "bookSourceName": "测试源(JSON修改)",
          "bookSourceUrl": "https://test.com"
        }
        """
        vm.send(.updateRawJson(editedJson))
        vm.send(.formatJson)
        #expect(vm.state.isDirty == true)

        // 切回表单模式，验证反序列化同步
        vm.send(.toggleJsonMode)
        #expect(vm.state.isJsonEditorPresented == false)
        #expect(vm.state.source.bookSourceName == "测试源(JSON修改)")

        // 测试错误 JSON 防护
        vm.send(.toggleJsonMode)
        vm.send(.updateRawJson("{ invalid json "))
        vm.send(.toggleJsonMode)
        // 应该停留并在 state 中提示错误
        #expect(vm.state.isJsonEditorPresented == true)
        #expect(vm.state.errorMessage != nil)
    }

    @Test("Test BookSourceEditViewModel Save and Dismiss Intents")
    @MainActor
    func viewModelSaveAndDismiss() async {
        let repo = BookSourceRepositoryImpl(modelContainer: ModelContainerProvider(inMemory: true).container)
        let useCase = SaveBookSourceUseCase(sourceRepository: repo)
        let vm = BookSourceEditViewModel(source: nil, saveUseCase: useCase)

        // 1. 修改未保存时请求退出 -> 触发弹窗
        vm.send(.updateField(key: "bookSourceName", value: "待保存源"))
        vm.send(.requestDismiss)
        #expect(vm.state.isDiscardAlertPresented == true)

        // 取消放弃
        vm.send(.cancelDiscard)
        #expect(vm.state.isDiscardAlertPresented == false)

        // 补充必填字段并保存
        vm.send(.updateField(key: "bookSourceUrl", value: "https://saved.com"))
        #expect(vm.state.canSave == true)

        vm.send(.save)

        // 稍作等待 Task 完成
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.state.isDirty == false)
        let savedSources = try? await repo.fetchSources()
        #expect(savedSources?.count == 1)
        #expect(savedSources?.first?.bookSourceName == "待保存源")
    }
}
