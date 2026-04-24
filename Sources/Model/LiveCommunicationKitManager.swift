//
//  LiveCommunicationKitManager.swift
//  AgoraCallKit
//
//  Apple LiveCommunicationKit 集成：iOS 17.4+ 可用的 VoIP 通话界面框架
//  作为 CallKit 的替代方案，用于规避 CallKit 可能存在的 AppStore 审核风险
//

import Foundation
import LiveCommunicationKit
import AVFoundation

/// LiveCommunicationKit 事件委托
public protocol LiveCommunicationKitManagerDelegate: AnyObject {
    /// 用户点击了接听
    func liveCommunicationKitDidAcceptCall()
    /// 用户点击了拒绝
    func liveCommunicationKitDidRejectCall()
    /// 通话超时未接听
    func liveCommunicationKitDidTimeout()
}

/// LiveCommunicationKit 管理器（iOS 17.4+）
/// 用于替代 CallKit，提供更简单的 VoIP 来电界面
/// LiveCommunicationKit 优势：
/// - 不需要配置 CXProvider，避免审核风险
/// - 界面更简洁，适合简单的一对一通话场景
/// - 支持 Live Activity 和动态岛（iOS 16.1+）
@available(iOS 17.4, *)
public class LiveCommunicationKitManager: NSObject {
    
    public static let shared = LiveCommunicationKitManager()
    
    public weak var delegate: LiveCommunicationKitManagerDelegate?
    
    /// 当前通话的请求对象
    private var currentRequest: LCVideoCallRequest?
    
    /// 当前通话的 UUID
    private var currentCallUUID: UUID?
    
    /// 是否正在显示来电界面
    public private(set) var isShowingIncomingCall = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - 配置检查
    
    /// 检查是否应该使用 LiveCommunicationKit
    /// - 注意：只要 isLiveCommunicationKitEnabled = true，iOS 17.4+ 就会使用 LiveCommunicationKit
    /// - isCallKitEnabled 仅在 iOS < 17.4 时作为 CallKit 的回退开关
    public static var isEnabled: Bool {
        return CallConfiguration.shared.isLiveCommunicationKitEnabled
    }
    
    // MARK: - 报告来电
    
    /// 向系统报告收到来电（收到 VoIP 推送后调用）
    /// - Parameters:
    ///   - uuid: 通话唯一标识
    ///   - callerName: 主叫方名称
    ///   - isVideo: 是否为视频通话
    ///   - update: 可选的更新回调（用于更新来电界面信息）
    public func reportIncomingCall(uuid: UUID, callerName: String, isVideo: Bool, update: ((LCUpdate) -> Void)? = nil) {
        guard LiveCommunicationKitManager.isEnabled else {
            print("[LiveCommunicationKitManager] LiveCommunicationKit 未启用，跳过报告来电")
            return
        }
        
        currentCallUUID = uuid
        
        let updateObj = LCUpdate()
        updateObj.update = { update in
            update.callerName = callerName
            update.hasVideo = isVideo
            // 设置图标（如果有配置）
            if let iconName = CallConfiguration.shared.callKitIconName,
               let imageData = UIImage(named: iconName)?.pngData() {
                update.iconData = imageData
            }
            // 设置铃声（复用 CallSoundService 配置）
            if let ringtoneSound = CallConfiguration.shared.callKitRingtoneSound {
                update.ringtoneSoundName = ringtoneSound
            } else if let incomingPath = CallSoundService.shared.incomingRingtonePath {
                update.ringtoneSoundName = (incomingPath as NSString).lastPathComponent
            }
            // 调用自定义更新逻辑
            update?(update)
        }
        
        let request = LCVideoCallRequest(uuid: uuid, update: updateObj)
        request.isVideo = isVideo
        
        currentRequest = request
        
        // 显示来电界面
        request.present { [weak self] error in
            if let error = error {
                print("[LiveCommunicationKitManager] 显示来电界面失败: \(error.localizedDescription)")
                self?.currentCallUUID = nil
                self?.currentRequest = nil
            } else {
                print("[LiveCommunicationKitManager] 来电界面已显示: \(callerName)")
                self?.isShowingIncomingCall = true
            }
        }
    }
    
    /// 更新来电界面信息（如头像、昵称等）
    public func updateIncomingCall(callerName: String? = nil, hasVideo: Bool? = nil, avatarData: Data? = nil) {
        guard isShowingIncomingCall, let uuid = currentCallUUID else { return }
        
        let update = LCUpdate()
        update.update = { update in
            if let name = callerName {
                update.callerName = name
            }
            if let video = hasVideo {
                update.hasVideo = video
            }
            if let data = avatarData {
                update.iconData = data
            }
        }
        
        LCVideoCallRequest.updateIncomingCall(for: uuid, with: update) { error in
            if let error = error {
                print("[LiveCommunicationKitManager] 更新来电界面失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 通话状态报告
    
    /// 报告通话已接通
    public func reportCallConnected() {
        guard isShowingIncomingCall, let uuid = currentCallUUID else { return }
        
        LCVideoCallRequest.reportOutgoingCall(for: uuid, connectedAt: Date()) { error in
            if let error = error {
                print("[LiveCommunicationKitManager] 报告通话接通失败: \(error.localizedDescription)")
            } else {
                print("[LiveCommunicationKitManager] 通话已接通")
            }
        }
        isShowingIncomingCall = false
    }
    
    /// 报告通话已结束
    public func reportCallEnded(reason: String = "ended") {
        guard let uuid = currentCallUUID else { return }
        
        LCVideoCallRequest.endCall(for: uuid) { [weak self] error in
            if let error = error {
                print("[LiveCommunicationKitManager] 报告通话结束失败: \(error.localizedDescription)")
            } else {
                print("[LiveCommunicationKitManager] 通话已结束: \(reason)")
            }
            self?.currentCallUUID = nil
            self?.currentRequest = nil
            self?.isShowingIncomingCall = false
        }
    }
    
    // MARK: - 主动操作
    
    /// 主动结束通话
    public func endCall() {
        reportCallEnded(reason: "userEnded")
    }
    
    /// 标记为已接听
    public func markCallAccepted() {
        isShowingIncomingCall = false
    }
    
    /// 标记为已拒绝
    public func markCallRejected() {
        isShowingIncomingCall = false
        currentCallUUID = nil
        currentRequest = nil
    }
}

// MARK: - LCVideoCallRequestDelegate

@available(iOS 17.4, *)
extension LiveCommunicationKitManager: LCVideoCallRequestDelegate {
    
    public func videoCallRequestDidAccept(_ request: LCVideoCallRequest) {
        print("[LiveCommunicationKitManager] 用户点击了接听")
        isShowingIncomingCall = false
        delegate?.liveCommunicationKitDidAcceptCall()
    }
    
    public func videoCallRequestDidReject(_ request: LCVideoCallRequest) {
        print("[LiveCommunicationKitManager] 用户点击了拒绝")
        isShowingIncomingCall = false
        delegate?.liveCommunicationKitDidRejectCall()
    }
    
    public func videoCallRequest(_ request: LCVideoCallRequest, didNotRespond reason: LCVideoCallRequest.DidNotRespondReason) {
        print("[LiveCommunicationKitManager] 用户未响应: \(reason.rawValue)")
        isShowingIncomingCall = false
        currentCallUUID = nil
        currentRequest = nil
        delegate?.liveCommunicationKitDidTimeout()
    }
}
