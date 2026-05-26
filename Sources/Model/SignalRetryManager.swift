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

    /// 串行队列，保证多个重试操作不交错执行
    private let serialQueue = DispatchQueue(label: "com.agora.signalretry.serial", qos: .utility)

    private init() {}

    /// 带指数退避重试的信令发送（纯异步，不阻塞线程）
    /// - Parameters:
    ///   - policy: 重试策略
    ///   - operation: 信令发送闭包（每次调用应执行实际发送逻辑）
    ///   - completion: 最终完成回调（仅调用一次，在成功或所有重试失败后）
    public func sendWithRetry(
        policy: RetryPolicy = .default,
        operation: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        serialQueue.async {
            self.attemptSend(policy: policy, remainingRetries: policy.maxRetries,
                             currentDelay: policy.initialDelay,
                             action: operation, completion: completion)
        }
    }

    private func attemptSend(
        policy: RetryPolicy,
        remainingRetries: Int,
        currentDelay: TimeInterval,
        action: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        action { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                if remainingRetries > 0 {
                    let nextRetries = remainingRetries - 1
                    let delay = currentDelay
                    let nextDelay = min(currentDelay * policy.multiplier, policy.maxDelay)
                    AgoraLogger.info("信令发送失败，\(String(format: "%.1f", delay))s 后重试（剩余 \(nextRetries) 次）: \(error.localizedDescription)", module: "SignalRetryManager")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.serialQueue.async {
                            self.attemptSend(policy: policy, remainingRetries: nextRetries,
                                             currentDelay: nextDelay,
                                             action: action, completion: completion)
                        }
                    }
                } else {
                    AgoraLogger.info("信令发送失败，重试次数已用完: \(error.localizedDescription)", module: "SignalRetryManager")
                    completion(.failure(error))
                }
            }
        }
    }
}
