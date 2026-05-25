//
//  CallState.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

// MARK: - 通话状态枚举

public enum CallState: Equatable {
    case idle              // 空闲，无通话
    case calling           // 正在呼叫（主叫等待接听）
    case incoming          // 收到来电（被叫等待选择）
    case connecting        // 连接中（加入频道）
    case connected         // 通话中
    case reconnecting      // 重连中
    case disconnected      // 已断开（通话结束）
    case failed            // 失败
}

// MARK: - 通话结束原因枚举
// 用于替代 CallKit 的 CXCallEndedReason（中国区 App Store 审核不允许使用 CallKit）

public enum CallEndedReason: Equatable {
    case failed            // 通话失败
    case localEnded        // 本地主动挂断
    case remoteEnded       // 对方结束通话
    case unanswered        // 对方未接听
    case answeredElsewhere // 已在其他设备接听
    case declinedElsewhere // 已在其他设备拒绝
}

#if !CHINA_APP_STORE

import CallKit

extension CallEndedReason {
    
    /// 转换为 CXCallEndedReason（用于 CallKit 场景）
    public var cxCallEndedReason: CXCallEndedReason {
        switch self {
        case .failed:            return .failed
        case .localEnded:        return .remoteEnded  // CallKit 无 localEnded，映射为 remoteEnded
        case .remoteEnded:       return .remoteEnded
        case .unanswered:         return .unanswered
        case .answeredElsewhere: return .answeredElsewhere
        case .declinedElsewhere: return .declinedElsewhere
        }
    }
    
    /// 从 CXCallEndedReason 转换
    public init(cxCallEndedReason: CXCallEndedReason) {
        switch cxCallEndedReason {
        case .failed:            self = .failed
        case .remoteEnded:       self = .remoteEnded
        case .unanswered:         self = .unanswered
        case .answeredElsewhere:  self = .answeredElsewhere
        case .declinedElsewhere: self = .declinedElsewhere
        @unknown default:        self = .failed
        }
    }
}
#endif
