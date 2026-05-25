//
//  CurrentUserProvider.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// 当前登录用户信息提供者协议，由 App 层实现
public protocol CurrentUserProvider: AnyObject {
    /// 当前用户 ID，未登录时返回 nil
    var currentUserId: String? { get }
    /// 当前用户名称，未登录时返回 nil
    var currentUserName: String? { get }
}
