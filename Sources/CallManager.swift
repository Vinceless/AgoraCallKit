//
//  CallManager.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation
import AgoraRtcKit

public class CallManager {
    
    public static let shared = CallManager()
    
    // MARK: - 外部注入组件
    public var signalDelegate: CallSignalDelegate?
    public var tokenProvider: TokenProvider?
    public var userProvider: CurrentUserProvider?
    public var uiDelegate: CallUIDelegate?
    public let engine = AgoraEngineManager.shared
    
    // MARK: - 内部组件
    public var currentState: CallState = .idle {
        didSet {
            uiDelegate?.callStateDidChange(currentState)
        }
    }
    
    // 当前通话信息
    private var currentCallType: CallType?
    private var currentChannel: String?
    private var currentRemoteUserId: String?
    private var currentRemoteUserName: String?
    private var currentToken: String?
    private var localUid: UInt = 0
    private var remoteUid: UInt?
    private var callStartTime: Date?
    private var durationTimer: Timer?
    
    // 群组通话用户列表（uid -> userId）
    private var remoteUsers: [UInt: String] = [:]
    
    // 信令监听器（由 CallManager 实现，并注册到 signalDelegate）
    private let signalListener = CallManagerSignalListener()
    
    private init() {
        engine.delegate = self
        signalListener.manager = self
        signalDelegate?.setListener(signalListener)
    }
    
    // MARK: - 公共方法
    
    /// 发起单聊通话
    public func startCall(toUserId: String, userName: String?, channelName: String, callType: CallType, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard currentState == .idle else {
            let error = NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "已有通话进行中"])
            completion?(.failure(error))
            return
        }
        
        currentCallType = callType
        currentRemoteUserId = toUserId
        currentRemoteUserName = userName
        currentState = .calling
        uiDelegate?.callStateDidChange(.calling)
        
//        let channelName = generateChannelName(for: toUserId)
        currentChannel = channelName
        
        guard let userId = userProvider?.currentUserId else {
            failWithError("无法获取当前用户ID", completion: completion)
            return
        }
        
        tokenProvider?.fetchToken(channelName: channelName, userId: userId) { [weak self] result in
            switch result {
            case .success(let token):
                self?.currentToken = token
                let success = self?.engine.joinChannel(channelName, token: token, uid: 0, isVideoCall: callType == .video) ?? false
                if !success {
                    self?.failWithError("加入频道失败", completion: completion)
                    return
                }
                self?.signalDelegate?.sendCallRequest(toUserId: toUserId, channelName: channelName, token: token, callType: callType) { result in
                    if case .failure(let error) = result {
                        self?.failWithError(error.localizedDescription, completion: completion)
                    } else {
                        completion?(.success(()))
                    }
                }
            case .failure(let error):
                self?.failWithError(error.localizedDescription, completion: completion)
            }
        }
    }
    
    /// 发起群聊通话
    public func startGroupCall(channelName: String, callType: CallType, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard currentState == .idle else {
            completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "已有通话进行中"])))
            return
        }
        
        currentCallType = callType
        currentState = .calling
        currentChannel = channelName
        
        guard let userId = userProvider?.currentUserId else {
            completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取当前用户ID"])))
            return
        }
        
        tokenProvider?.fetchToken(channelName: channelName, userId: userId) { [weak self] result in
            switch result {
            case .success(let token):
                self?.currentToken = token
                let success = self?.engine.joinChannel(channelName, token: token, uid: 0, isVideoCall: callType == .video) ?? false
                if success {
                    self?.currentState = .connected
                    self?.callStartTime = Date()
                    self?.startDurationTimer()
                    completion?(.success(()))
                } else {
                    completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "加入频道失败"])))
                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    /// 接听来电（在收到 didReceiveIncomingCall 后调用）
    public func acceptCall() {
        guard currentState == .incoming,
              let channel = currentChannel,
              let token = currentToken,
              let callType = currentCallType,
              let userId = userProvider?.currentUserId else {
            return
        }
        
        let success = engine.joinChannel(channel, token: token, uid: 0, isVideoCall: callType == .video)
        if !success {
            failWithError("加入频道失败")
            return
        }
        
        if let remoteId = currentRemoteUserId {
            signalDelegate?.sendAcceptResponse(toUserId: remoteId) { _ in }
        }
        
        currentState = .connected
        callStartTime = Date()
        startDurationTimer()
    }
    
    /// 拒绝来电
    public func rejectCall() {
        guard currentState == .incoming, let remoteId = currentRemoteUserId else { return }
        signalDelegate?.sendRejectResponse(toUserId: remoteId, reason: nil) { _ in }
        resetCall()
        uiDelegate?.didDisconnect(error: nil)
    }
    
    /// 挂断当前通话
    public func hangUp() {
        guard currentState != .idle, currentState != .disconnected else { return }
        
        if let remoteId = currentRemoteUserId, currentState == .connected {
            signalDelegate?.sendHangupSignal(toUserId: remoteId) { _ in }
        } else if let remoteId = currentRemoteUserId, currentState == .calling {
            signalDelegate?.sendCancelSignal(toUserId: remoteId) { _ in }
        }
        
        engine.leaveChannel()
        resetCall()
        uiDelegate?.didDisconnect(error: nil)
    }
    
    /// 获取当前通话时长
    public func getCurrentDuration() -> TimeInterval {
        guard let start = callStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    /// 当前是否在通话中
    public var isInCall: Bool {
        switch currentState {
        case .calling, .incoming, .connecting, .connected, .reconnecting:
            return true
        default:
            return false
        }
    }
    
    /// 当前通话类型
    public var getCurrentCallType: CallType? { currentCallType }
    
    /// 当前远程用户ID（单聊）
    public var getCurrentRemoteUserId: String? { currentRemoteUserId }
    
    /// 获取群组所有远端用户（uid -> userId）
    public func getAllRemoteUsers() -> [UInt: String] {
        return remoteUsers
    }
    
    // MARK: - 音视频控制（转发给引擎）
    public func muteAudio(_ mute: Bool) {
        engine.muteLocalAudio(mute)
    }
    
    public func muteVideo(_ mute: Bool) {
        engine.muteLocalVideo(mute)
    }
    
    public func setSpeakerEnabled(_ enabled: Bool) {
        engine.setSpeakerEnabled(enabled)
    }
    
    public func switchCamera() {
        engine.switchCamera()
    }
    
    public func setupLocalVideoView(_ view: UIView) {
        engine.setupLocalVideoView(view)
    }
    
    public func setupRemoteVideoView(_ view: UIView, forUid uid: UInt) {
        engine.setupRemoteVideoView(view, forUid: uid)
    }
    
    // MARK: - 信令接收（由 App 层信令模块调用）
    
    /// 收到单聊来电（由 App 层调用）
    public func receiveIncomingCall(fromUserId: String, channelName: String, token: String, callType: CallType) {
        guard currentState == .idle else {
            signalDelegate?.sendRejectResponse(toUserId: fromUserId, reason: "busy") { _ in }
            return
        }
        currentState = .incoming
        currentCallType = callType
        currentChannel = channelName
        currentToken = token
        currentRemoteUserId = fromUserId
        uiDelegate?.didReceiveIncomingCall(fromUserId: fromUserId,
                                           userName: nil,
                                           callType: callType,
                                           channelName: channelName,
                                           token: token)
    }
    
    /// 收到群聊来电（由 App 层调用）
    public func receiveIncomingGroupCall(fromUserId: String, channelName: String, token: String, callType: CallType) {
        // 群聊来电处理与单聊类似，但可能需要在 UI 中区分
        receiveIncomingCall(fromUserId: fromUserId, channelName: channelName, token: token, callType: callType)
    }
    
    /// 对方接受通话
    public func onCallAccepted(fromUserId: String) {
        guard currentState == .calling, currentRemoteUserId == fromUserId else { return }
        currentState = .connected
        callStartTime = Date()
        startDurationTimer()
    }
    
    /// 对方拒绝通话
    public func onCallRejected(fromUserId: String, reason: String?) {
        guard currentState == .calling, currentRemoteUserId == fromUserId else { return }
        resetCall()
        uiDelegate?.didDisconnect(error: nil)
    }
    
    /// 对方挂断
    public func onCallHangup(fromUserId: String) {
        guard currentState == .connected, currentRemoteUserId == fromUserId else { return }
        resetCall()
        uiDelegate?.didDisconnect(error: nil)
    }
    
    /// 对方取消通话
    public func onCallCanceled(fromUserId: String) {
        guard currentState == .calling, currentRemoteUserId == fromUserId else { return }
        resetCall()
        uiDelegate?.didDisconnect(error: nil)
    }
    
    // MARK: - 内部方法
    private func generateChannelName(for remoteUserId: String) -> String {
        guard let myId = userProvider?.currentUserId else { return "call_\(remoteUserId)" }
        let ids = [myId, remoteUserId].sorted()
        return "call_\(ids[0])_\(ids[1])"
    }
    
    private func failWithError(_ message: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let error = NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        uiDelegate?.didOccurError(error)
        resetCall()
        uiDelegate?.didDisconnect(error: error)
        completion?(.failure(error))
    }
    
    private func resetCall() {
        stopDurationTimer()
        currentState = .idle
        currentCallType = nil
        currentChannel = nil
        currentRemoteUserId = nil
        currentRemoteUserName = nil
        currentToken = nil
        remoteUid = nil
        callStartTime = nil
        remoteUsers.removeAll()
    }
    
    private func startDurationTimer() {
        stopDurationTimer()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.callStartTime else { return }
            let duration = Date().timeIntervalSince(start)
            self.uiDelegate?.didUpdateDuration(duration)
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

// MARK: - CallSignalListener 实现
private class CallManagerSignalListener: CallSignalListener {
    weak var manager: CallManager?
    
    func onReceiveCall(fromUserId: String, channelName: String, token: String, callType: CallType) {
        manager?.receiveIncomingCall(fromUserId: fromUserId, channelName: channelName, token: token, callType: callType)
    }
    func onCallAccepted(fromUserId: String) {
        manager?.onCallAccepted(fromUserId: fromUserId)
    }
    func onCallRejected(fromUserId: String, reason: String?) {
        manager?.onCallRejected(fromUserId: fromUserId, reason: reason)
    }
    func onCallHangup(fromUserId: String) {
        manager?.onCallHangup(fromUserId: fromUserId)
    }
    func onCallCanceled(fromUserId: String) {
        manager?.onCallCanceled(fromUserId: fromUserId)
    }
}

// MARK: - AgoraEngineDelegate
extension CallManager: AgoraEngineDelegate {
    public func engine(_ engine: AgoraEngineManager, didJoinChannel channel: String, uid: UInt) {
        localUid = uid
        if currentState == .calling || currentState == .incoming {
            currentState = .connected
            callStartTime = Date()
            startDurationTimer()
        }
        uiDelegate?.didConnect(withUid: uid)
    }
    
    public func engine(_ engine: AgoraEngineManager, didLeaveChannel channel: String) {
        // 已经在 hangUp 中重置，这里不需要额外操作
    }
    
    public func engine(_ engine: AgoraEngineManager, didJoinedOfUid uid: UInt) {
        // 群组通话时，可能会有多个远端用户加入
        if let userId = currentRemoteUserId, uid == remoteUid {
            // 单聊场景，直接保存
            remoteUid = uid
            uiDelegate?.remoteUserDidJoin(uid: uid, userId: userId)
        } else {
            // 群聊场景，我们需要知道用户的 userId，但这里只有 uid
            // 实际项目中可以通过其他方式映射 uid 到 userId，或者由上层提供
            let userId = "user_\(uid)"
            remoteUsers[uid] = userId
            uiDelegate?.remoteUserDidJoin(uid: uid, userId: userId)
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, didOfflineOfUid uid: UInt) {
        if let userId = remoteUsers[uid] {
            remoteUsers.removeValue(forKey: uid)
            uiDelegate?.remoteUserDidLeave(uid: uid, userId: userId)
        } else if uid == remoteUid {
            // 单聊的远端离开
            let userId = currentRemoteUserId ?? "\(uid)"
            uiDelegate?.remoteUserDidLeave(uid: uid, userId: userId)
            if currentState == .connected {
                hangUp()
            }
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, didOccurError error: Error) {
        uiDelegate?.didOccurError(error)
        hangUp()
    }
    
    public func engine(_ engine: AgoraEngineManager, localVideoMuted muted: Bool) {
        // 可通知 UI 更新本地视频静音图标
    }
    
    public func engine(_ engine: AgoraEngineManager, remoteVideoMuted muted: Bool, ofUid uid: UInt) {
        // 可通知 UI 更新远端视频占位图
    }
    
    public func engine(_ engine: AgoraEngineManager, connectionStateChanged state: AgoraConnectionState) {
        switch state {
        case .connecting:
            if currentState == .calling || currentState == .incoming {
                currentState = .connecting
            }
        case .connected:
            if currentState == .connecting {
                currentState = .connected
            }
        case .reconnecting:
            currentState = .reconnecting
        case .disconnected:
            if currentState == .connected || currentState == .reconnecting {
                hangUp()
            }
        default:
            break
        }
    }
}
