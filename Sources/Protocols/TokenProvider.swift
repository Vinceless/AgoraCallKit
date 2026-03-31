//
//  TokenProvider.swift
//  CallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// Token 获取协议（由 App 层实现）
public protocol TokenProvider: AnyObject {
    /// 获取声网 Token
    /// - Parameters:
    ///   - channelName: 频道名
    ///   - userId: 用户ID（用于生成 Token）
    ///   - completion: 回调，成功返回 Token 字符串
    func fetchToken(channelName: String, userId: String, completion: @escaping (Result<String, Error>) -> Void)
}
