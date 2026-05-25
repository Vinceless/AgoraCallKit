//
//  SignalRetryManager.swift
//  AgoraCallKit
//
//  信令重试管理器：指数退避重试发送失败的信令
//

import Foundation

/// 信令重试管理器
public final class SignalRetryManager {

    /// 重试策略
    public struct RetryPolicy {
        /// 最大重试次数（默认 3）
        public let maxRetries: Int
        /// 初始退避延迟（秒，默认 1.0）
        public let initialDelay: TimeInterval
        /// 退避倍率（默认 2.0，即 1s → 2s → 4s）
        public let multiplier: TimeInterval
        /// 最大退避延迟（秒，默认 10.0）
        public let maxDelay: TimeInterval

        public init(maxRetries: Int = 3, initialDelay: TimeInterval = 1.0, multiplier: TimeInterval = 2.0, maxDelay: TimeInterval = 10.0) {
            self.maxRetries = maxRetries
            self.initialDelay = initialDelay
            self.multiplier = multiplier
            self.maxDelay = maxDelay
        }

        public static let `default` = RetryPolicy()
    }

    /// 默认策略
    public static let shared = SignalRetryManager()

    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    private init() {}

    /// 带指数退避重试的信令发送
    /// - Parameters:
    ///   - policy: 重试策略
    ///   - operation: 信令发送闭包（每次调用应执行实际发送逻辑）
    ///   - completion: 最终完成回调（仅调用一次，在成功或所有重试失败后）
    public func sendWithRetry(
        policy: RetryPolicy = .default,
        operation: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let operationBlock = RetryableOperation(policy: policy, action: operation, completion: completion)
        operationQueue.addOperation(operationBlock)
    }
}

// MARK: - 内部实现

private final class RetryableOperation: Operation {

    private let policy: SignalRetryManager.RetryPolicy
    private let action: (@escaping (Result<Void, Error>) -> Void) -> Void
    private let completion: (Result<Void, Error>) -> Void
    private var remainingRetries: Int
    private var currentDelay: TimeInterval

    init(policy: SignalRetryManager.RetryPolicy,
         action: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void,
         completion: @escaping (Result<Void, Error>) -> Void) {
        self.policy = policy
        self.action = action
        self.completion = completion
        self.remainingRetries = policy.maxRetries
        self.currentDelay = policy.initialDelay
        super.init()
    }

    override func main() {
        attemptSend()
    }

    private func attemptSend() {
        guard !isCancelled else { return }

        let semaphore = DispatchSemaphore(value: 0)
        var sendResult: Result<Void, Error>?

        action { result in
            sendResult = result
            semaphore.signal()
        }

        semaphore.wait()

        guard let result = sendResult else {
            handleRetryOrFail(with: NSError(domain: "SignalRetryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "信令发送无响应"]))
            return
        }

        switch result {
        case .success:
            completion(.success(()))
        case .failure(let error):
            if remainingRetries > 0 && !isCancelled {
                remainingRetries -= 1
                let delay = currentDelay
                currentDelay = min(currentDelay * policy.multiplier, policy.maxDelay)
                print("[SignalRetryManager] 信令发送失败，\(delay)s 后重试（剩余 \(remainingRetries) 次）: \(error.localizedDescription)")
                Thread.sleep(forTimeInterval: delay)
                attemptSend()
            } else {
                print("[SignalRetryManager] 信令发送失败，重试次数已用完: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}
