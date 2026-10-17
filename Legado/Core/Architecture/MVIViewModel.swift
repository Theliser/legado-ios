import Combine
import Foundation
import SwiftUI

/// 标识视图状态协议，要求必须遵循 Equatable 保证状态变更可追踪
public protocol ViewState: Equatable {}

/// 标识用户或系统交互意图协议
public protocol ViewIntent {}

/// 标识单次副作用事件（如 Toast、路由跳转、震动等）
public protocol ViewEffect {}

/// 空副作用默认实现，用于无需处理副作用的模块
public enum EmptyEffect: ViewEffect, Equatable {}

/// MVI ViewModel 核心协议标准
@MainActor
public protocol MVIViewModelProtocol: ObservableObject {
    associatedtype State: ViewState
    associatedtype Intent: ViewIntent
    associatedtype Effect: ViewEffect

    var state: State { get }
    var effectPublisher: AnyPublisher<Effect, Never> { get }

    func send(_ intent: Intent)
}

/// MVI ViewModel 基础抽象类
@MainActor
open class BaseMVIViewModel<State: ViewState, Intent: ViewIntent, Effect: ViewEffect>: MVIViewModelProtocol {
    @Published public private(set) var state: State

    private let effectSubject = PassthroughSubject<Effect, Never>()

    public var effectPublisher: AnyPublisher<Effect, Never> {
        effectSubject.eraseToAnyPublisher()
    }

    public init(initialState: State) {
        self.state = initialState
    }

    /// 发送交互意图由子类具体处理
    open func send(_: Intent) {
        fatalError("send(_:) has not been implemented by subclass")
    }

    /// 更新当前唯一状态
    public func updateState(_ update: (inout State) -> Void) {
        var newState = state
        update(&newState)
        state = newState
    }

    /// 发射一次性副作用
    public func emitEffect(_ effect: Effect) {
        effectSubject.send(effect)
    }
}
