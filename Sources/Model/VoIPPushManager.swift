//
//  VoIPPushManager.swift
//  AgoraCallKit
//
//  VoIP 推送管理器：注册 PushKit VoIP 推送，收到推送后处理来电
//
//  重要说明：
//  - iOS 13+ 要求 VoIP 推送必须配合 CallKit 或 LiveCommunicationKit 使用
//  - PKPushRegistry delegate 必须在返回前完成来电报告
//  - LiveCommunicationKit 需要在返回前调用 reportNewIncomingConversation
//  - 参考：Apple Bug FB16655952 - PushKit async delegate broken
//  - 解决方案：添加 Thread.sleep(forTimeInterval: 0.05) 确保执行时机
//

import Foundation
import PushKit
import Combine

/// VoIP 推送 payload 解析代理，由 App 层实现
/// SDK 收到原始推送后，调用此代理让 App 将业务 payload 转换为 CallIncomingInfo
public protocol VoIPPushPayloadDelegate: AnyObject {
    /// SDK 收到 VoIP 推送，要求 App 将 payload 解析为通话信息
    /// - Parameters:
    ///   - payload: 推送原始 payload 字典
    ///   - completion: 解析完成后必须调用，传入 CallIncomingInfo；解析失败传 nil
    func voipPushManager(didReceivePayload payload: [AnyHashable: Any], completion: @escaping (CallIncomingInfo?) -> Void)
}

/// 来电信息结构体，由 App 层从推送 payload 中解析后返回给 SDK
public struct CallIncomingInfo {
    /// 服务端返回的通话标识符（用于后续信令关联）
    public let callID: String
    /// 来电方用户ID
    public let fromUserId: String
    /// 频道名
    public let channelName: String
    /// Agora Token
    public let token: String
    /// 通话类型
    public let callType: CallType
    /// 来电方昵称
    public let callerName: String
    /// 来电方头像 URL
    public let callerAvatar: String
    
    public init(callID: String, fromUserId: String, channelName: String, token: String, callType: CallType, callerName: String, callerAvatar: String) {
        self.callID = callID
        self.fromUserId = fromUserId
        self.channelName = channelName
        self.token = token
        self.callType = callType
        self.callerName = callerName
        self.callerAvatar = callerAvatar
    }
}

/// VoIP 推送管理器（SDK 内置）
/// 负责 PushKit 注册、接收推送，并通过 VoIPPushPayloadDelegate 让 App 解析业务数据
public class VoIPPushManager: NSObject {
    
    public static let shared = VoIPPushManager()
    
    /// App 层实现的 payload 解析代理
    public weak var payloadDelegate: VoIPPushPayloadDelegate?
    
    /// VoIP Token 发布器（Data 类型，用于极光推送等）
    public let voipTokenPublisher = CurrentValueSubject<Data, Never>(Data())
    
    /// PushKit 注册对象（需强引用保持存活）
    private var pushRegistry: PKPushRegistry?
    
    /// 最后一次收到的推送 payload（用于调试和状态追踪）
    private var lastPayload: [AnyHashable: Any]?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 初始化
    
    /// 注册 PushKit VoIP 推送（App 启动时调用）
    public func registerForVoIPPush() {
        // 使用私有队列初始化 PKPushRegistry，避免与主线程冲突
//        let queue = DispatchQueue(label: "com.agoracallkit.voippush", qos: .userInteractive)
//        let registry = PKPushRegistry(queue: queue)
        let registry = PKPushRegistry(queue: DispatchQueue.main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        self.pushRegistry = registry
        
        print("[VoIPPushManager] 已注册 PushKit VoIP 推送)")
        
    }
    
    /// 清除最后一次推送的 payload 记录
    public func clearLastPayload() {
        lastPayload = nil
        print("[VoIPPushManager] 已清除推送记录")
    }
}

// MARK: - PKPushRegistryDelegate

extension VoIPPushManager: PKPushRegistryDelegate {
    
    /// VoIP Token 更新
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        voipTokenPublisher.send(pushCredentials.token)
        print("[VoIPPushManager] VoIP Token 更新")
    }
    
    /// 收到 VoIP 推送
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping @Sendable () -> Void) {
        print("[VoIPPushManager] 收到 VoIP 推送")
        
        lastPayload = payload.dictionaryPayload
        
        guard type == .voIP else {
            completion()
            return
        }
        
        guard let payloadDelegate = payloadDelegate else {
            print("[VoIPPushManager] ⚠️ 未设置 payloadDelegate，无法解析推送")
            completion()
            return
        }
        
        // 解析 payload
        payloadDelegate.voipPushManager(didReceivePayload: payload.dictionaryPayload) { [weak self] info in
            guard let self = self else { completion(); return }
            
            if let info = info {
                // 解析成功，交给 CallManager 处理来电
                self.handleIncomingCall(info: info) { success in
                    if !success {
                        print("[VoIPPushManager] ⚠️ 系统来电界面显示失败")
                    }
                    completion()
                }
            } else {
                print("[VoIPPushManager] ⚠️ App 解析 payload 返回 nil，忽略此推送")
                completion()
            }
        }
    }
    
    /// VoIP 推送处理失败
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("[VoIPPushManager] VoIP Token 失效")
        voipTokenPublisher.send(Data())
    }
    
    // MARK: - 内部处理
    
    /// 将解析后的来电信息交给 CallManager 处理
    private func handleIncomingCall(info: CallIncomingInfo, completion: @escaping (Bool) -> Void) {
        let remoteUser = CallUser(
            userId: info.fromUserId,
            uid: UInt(info.fromUserId) ?? 0,
            name: info.callerName,
            avatar: info.callerAvatar
        )
        
        CallManager.shared.receiveIncomingCall(
            callID: info.callID,
            from: remoteUser,
            channelName: info.channelName,
            token: info.token,
            callType: info.callType,
            incomingType: .voIPPush,
            systemUICompletion: completion
        )
    }

}
