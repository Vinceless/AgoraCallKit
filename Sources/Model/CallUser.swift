//
//  CallUser.swift
//  AgoraCallKit
//
//  Created by Vince on 2021/12/7.
//

import Foundation

// MARK: - 用户信息结构体

public struct AgoraUser {
    public let uid: UInt
    public var isAudioMuted: Bool = false
    public var isVideoMuted: Bool = false
    public var videoView: UIView?
    public var isLocal: Bool = false
    
    public init(uid: UInt, isLocal: Bool = false) {
        self.uid = uid
        self.isLocal = isLocal
    }
}

// MARK: - 用户信息

public struct CallUser {
    public let uid: UInt
    public let name: String
    public let avatar: String
    public var isAudioMuted: Bool = false
    public var isVideoMuted: Bool = false
    public var isLocal: Bool = false
    
    public init(uid: UInt, name: String, avatar: String = "", isLocal: Bool = false) {
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.isLocal = isLocal
    }
}
