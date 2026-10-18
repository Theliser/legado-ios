import Foundation

// MARK: - 书源连通性体检与批量维护扩展

extension SourceManageViewModel {
    /// 启动批量书源健康体检
    func startBatchHealthCheck() {
        guard !state.isCheckingHealth else { return }
        let allSources = state.sources
        guard !allSources.isEmpty else {
            emitEffect(.showToast("书源列表为空，无法进行体检"))
            return
        }

        healthCheckTask?.cancel()
        updateState {
            $0.isCheckingHealth = true
            $0.healthReports = [:]
            $0.healthCheckProgress = (0, allSources.count)
        }
        emitEffect(.hapticFeedback)

        healthCheckTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.checkHealthUseCase.checkBatch(
                sources: allSources,
                concurrency: 5) { [weak self] report, completed, total in
                    Task { @MainActor in
                        self?.updateState { state in
                            state.healthReports[report.sourceUrl] = report
                            state.healthCheckProgress = (completed, total)
                        }
                    }
                }

            guard !Task.isCancelled else { return }
            self.updateState {
                $0.isCheckingHealth = false
                $0.healthCheckProgress = nil
            }
            let invalidCount = self.state.healthReports.values.filter { !$0.isHealthy }.count
            if invalidCount > 0 {
                self.emitEffect(.showToast("体检完成：发现 \(invalidCount) 个异常书源"))
            } else {
                self.emitEffect(.showToast("全量体检完成：所有书源均可正常访问！"))
            }
            self.emitEffect(.hapticFeedback)
        }
    }

    /// 终止当前进行中的健康体检
    func stopBatchHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        updateState {
            $0.isCheckingHealth = false
            $0.healthCheckProgress = nil
        }
        emitEffect(.showToast("已停止书源体检"))
        emitEffect(.hapticFeedback)
    }

    /// 一键禁用体检发现的失效书源
    func disableInvalidSources() {
        let invalidUrls = state.healthReports.values.filter { !$0.isHealthy }.map(\.sourceUrl)
        guard !invalidUrls.isEmpty else {
            emitEffect(.showToast("暂未发现失效书源"))
            return
        }

        Task {
            for url in invalidUrls {
                try? await self.toggleEnabledUseCase.execute(sourceUrl: url, enabled: false)
            }
            self.loadAllSources()
            self.emitEffect(.showToast("已成功禁用 \(invalidUrls.count) 个失效书源"))
            self.emitEffect(.hapticFeedback)
        }
    }

    /// 一键删除体检发现的失效书源
    func deleteInvalidSources() {
        let invalidUrls = state.healthReports.values.filter { !$0.isHealthy }.map(\.sourceUrl)
        guard !invalidUrls.isEmpty else {
            emitEffect(.showToast("暂未发现失效书源"))
            return
        }

        Task {
            for url in invalidUrls {
                try? await self.deleteSourceUseCase.execute(sourceUrl: url)
            }
            self.loadAllSources()
            self.emitEffect(.showToast("已清理 \(invalidUrls.count) 个失效书源"))
            self.emitEffect(.hapticFeedback)
        }
    }
}
