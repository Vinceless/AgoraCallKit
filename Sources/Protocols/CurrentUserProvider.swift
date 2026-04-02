//
//  CurrentUserProvider.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// 当前登录用户信息提供者（由 App 层实现）
public protocol CurrentUserProvider: AnyObject {
    /// 当前用户ID
    var currentUserId: String { get }
    /// 当前用户昵称（可选，用于UI显示）
    var currentUserName: String { get }
}
