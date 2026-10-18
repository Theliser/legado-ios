import Foundation

extension BookshelfViewModel {
    /// 处理本地书籍文件导入 (TXT/EPUB)
    func handleImportLocalBook(url: URL) {
        guard let importUseCase = importLocalBookUseCase else {
            emitEffect(.showToast("未配置本地导入服务"))
            return
        }

        updateState { $0.isLoading = true }
        emitEffect(.hapticFeedback)

        Task {
            do {
                let book = try await importUseCase.execute(fileUrl: url)
                updateState { $0.isLoading = false }
                emitEffect(.showToast("成功导入书籍《\(book.name)》"))
                emitEffect(.hapticFeedback)
                send(.onAppear)
            } catch {
                updateState { $0.isLoading = false }
                emitEffect(.showToast("导入失败: \(error.localizedDescription)"))
            }
        }
    }
}
