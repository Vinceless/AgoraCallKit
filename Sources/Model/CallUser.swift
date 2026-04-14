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
    /// 业务用户ID（用于信令匹配，如 "1029"）
    public let userId: String
    /// 声网频道用户ID（加入频道后由引擎分配，如 1031）
    public var uid: UInt
    public let name: String
    public let avatar: String
    public var isAudioMuted: Bool = false
    public var isVideoMuted: Bool = false
    public var isLocal: Bool = false
    
    /// 初始化用户
    /// - Parameters:
    ///   - userId: 业务用户ID
    ///   - uid: 声网用户ID（未知时可传 0，加入频道后更新）
    ///   - name: 用户昵称
    ///   - avatar: 头像URL（可选）
    ///   - isLocal: 是否为本地用户
    public init(userId: String, uid: UInt = 0, name: String, avatar: String = "", isLocal: Bool = false) {
        self.userId = userId
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.isLocal = isLocal
    }
}
