import Foundation

/// 异步并发信号量计数器，用于对海量多书源并发抓取进行高吞吐限速与连接池流控
public actor AsyncSemaphore {
    private var permits: Int
    private let maxPermits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(value: Int) {
        precondition(value > 0, "AsyncSemaphore value must be greater than zero")
        self.permits = value
        self.maxPermits = value
    }

    /// 获取信号量许可，若当前许可已耗尽则挂起等待
    public func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 释放信号量许可并唤醒挂起的等待任务
    public func signal() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else if permits < maxPermits {
            permits += 1
        }
    }

    /// 在持有信号量许可的生命周期内安全执行闭包
    public func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await wait()
        defer {
            signal()
        }
        return try await operation()
    }

    /// 在持有信号量许可的生命周期内安全执行非抛出闭包
    public func withPermit<T: Sendable>(_ operation: @Sendable () async -> T) async -> T {
        await wait()
        defer {
            signal()
        }
        return await operation()
    }
}
