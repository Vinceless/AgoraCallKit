//
//  VoIPPushExamples.swift
//  Example
//
//  VoIP 推送集成示例
//

import Foundation
import UIKit
import AgoraCallKit

// MARK: - VoIP 推送集成示例

/// VoIP 推送处理示例类
class VoIPPushExamples: NSObject {
    
    /// 注册 VoIP 推送
    static func register() {
        VoIPPushManager.shared.payloadDelegate = shared
        VoIPPushManager.shared.registerForVoIPPush()
        print("[VoIPPush] 注册完成")
    }
    
    /// 清除 VoIP 推送状态
    static func clearState() {
        VoIPPushManager.shared.clearLastPayload()
        print("[VoIPPush] 状态已清除")
    }
    
    /// 获取单例实例
    static let shared = VoIPPushExamples()
    
    private override init() {
        super.init()
    }
}

// MARK: - VoIPPushPayloadDelegate

extension VoIPPushExamples: VoIPPushPayloadDelegate {
    
    /// 收到 VoIP 推送时的处理
    func voipPushManager(didReceivePayload payload: [AnyHashable: Any], completion: @escaping (CallIncomingInfo?) -> Void) {
        print("[VoIPPush] 收到推送: \(payload)")
        
        // ========== 关键：收到 VoIP 推送时启用系统来电界面 ==========
        CallConfiguration.shared.isCallKitEnabled = true
        
        // 如果启用 LiveCommunicationKit，iOS 17.4+ 会自动使用
        // CallConfiguration.shared.isLiveCommunicationKitEnabled = true
        
        // ========== 解析推送内容 ==========
        
        // 必填字段
        guard let fromUserId = payload["fromUserId"] as? String,
              let channelName = payload["channelName"] as? String,
              let token = payload["token"] as? String else {
            print("[VoIPPush] 推送内容不完整")
            completion(nil)
            return
        }
        
        // 可选字段
        let callTypeStr = payload["callType"] as? String ?? "voice"
        let callerName = payload["callerName"] as? String ?? fromUserId
        let callerAvatar = payload["callerAvatar"] as? String ?? ""
        
        let callType: CallType = (callTypeStr == "video") ? .video : .voice
        
        // ========== 构造 CallIncomingInfo ==========
        
        let info = CallIncomingInfo(
            fromUserId: fromUserId,
            channelName: channelName,
            token: token,
            callType: callType,
            callerName: callerName,
            callerAvatar: callerAvatar
        )
        
        print("[VoIPPush] 解析成功: \(callerName), type=\(callType)")
        completion(info)
    }
}

// MARK: - WebSocket 信令处理示例

class WebSocketSignalExamples {
    
    /// 处理 WebSocket 信令来电（不使用系统来电界面）
    static func handleIncomingCall(from user: CallUser, channelName: String, token: String, callType: CallType) {
        // 确保 WebSocket 信令来电不使用系统来电界面
        CallConfiguration.shared.isCallKitEnabled = false
        
        print("[WebSocket] 收到来电: \(user.name)")
        
        CallManager.shared.receiveIncomingCall(
            from: user,
            channelName: channelName,
            token: token,
            callType: callType
        )
    }
    
    /// 处理 WebSocket 信令来电（由 VoIP 推送触发，允许使用系统来电界面）
    static func handleIncomingCallFromVoIP(from user: CallUser, channelName: String, token: String, callType: CallType) {
        // VoIP 推送触发的来电允许使用系统来电界面
        CallConfiguration.shared.isCallKitEnabled = true
        
        print("[WebSocket] VoIP 触发来电: \(user.name)")
        
        CallManager.shared.receiveIncomingCall(
            from: user,
            channelName: channelName,
            token: token,
            callType: callType
        )
    }
    
    /// 处理对方接受通话
    static func handleCallAccepted(fromUserId: String) {
        CallManager.shared.onCallAccepted(fromUserId: fromUserId)
    }
    
    /// 处理对方拒绝通话
    static func handleCallRejected(fromUserId: String, reason: String?) {
        CallManager.shared.onCallRejected(fromUserId: fromUserId, reason: reason)
    }
    
    /// 处理对方挂断
    static func handleCallHangup(fromUserId: String) {
        CallManager.shared.onCallHangup(fromUserId: fromUserId)
    }
    
    /// 处理对方取消通话
    static func handleCallCanceled(fromUserId: String) {
        CallManager.shared.onCallCanceled(fromUserId: fromUserId)
    }
}

// MARK: - 通话状态重置示例

class CallStateResetExamples {
    
    /// 通话结束后重置状态
    static func resetAfterCall() {
        // 重置系统来电界面配置
        CallConfiguration.shared.isCallKitEnabled = false
        
        // 清除 VoIP 推送状态
        VoIPPushManager.shared.clearLastPayload()
        
        print("[状态重置] 已完成")
    }
}
