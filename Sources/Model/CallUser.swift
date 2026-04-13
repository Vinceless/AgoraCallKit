//
//  CallUser.swift
//  AgoraCallKit
//
//  Created by Vince on 2021/12/7.
//

import Foundation

// MARK: - 用户信息

/// 通话中的用户信息
public struct CallUser {
    public let uid: UInt
    public let name: String
    public let avatar: String
    public var isAudioMuted: Bool = false
    public var isVideoMuted: Bool = false
    public var isLocal: Bool = false
    
    /// 初始化用户
    /// - Parameters:
    ///   - uid: 声网用户ID
    ///   - name: 用户昵称
    ///   - avatar: 头像URL（可选）
    ///   - isLocal: 是否为本地用户
    public init(uid: UInt, name: String, avatar: String = "", isLocal: Bool = false) {
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.isLocal = isLocal
    }
}
