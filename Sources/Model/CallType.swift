//
//  CallType.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

// MARK: - 通话类型枚举

public enum CallType: String {
    case audio  // 音频通话
    case video  // 视频通话
    
    public var description: String { rawValue }
}

// MARK: - 通话模式枚举

public enum CallMode {
    case single         // 单聊
    case group          // 群聊
}
