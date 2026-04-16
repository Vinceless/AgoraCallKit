//
//  CallManager.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation
import AgoraRtcKit

/// 通话核心管理器，负责信令交互、状态管理、音视频控制
public class CallManager {
    
    public static let shared = CallManager()
    
    // MARK: - 日志
    private func log(_ message: String, function: String = #function) {
        print("[CallManager] \(function) | \(message) | currentState=\(currentState)")
    }
    
    // MARK: - 外部注入组件
    public var signalDelegate: CallSignalDelegate? {
        didSet { signalDelegate?.setListener(signalListener) }
    }
    public var tokenProvider: TokenProvider?
    public var userProvider: CurrentUserProvider?
    
    /// 多播 UI 委托：支持多个 CallUIDelegate 同时监听（弱引用，自动清理已销毁的 delegate）
    /// App 层的全局 delegate（如 AppCallUIDelegate）和当前通话 VC 各自独立注册
    public let uiDelegate = CallUIDelegateMulticast()
    
    public let engine = AgoraEngineManager.shared
    
    // MARK: - 内部状态
    public private(set) var isCaller: Bool = false
    
    public var currentState: CallState = .idle {
        didSet {
            if oldValue != currentState {
                log("状态变化: \(oldValue) → \(currentState)")
                let state = currentState
                // 声音/震动处理
                handleSoundForStateChange(from: oldValue, to: state)
                if Thread.isMainThread {
                    uiDelegate.callStateDidChange(state)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.uiDelegate.callStateDidChange(state)
                    }
                }
            }
        }
    }
    
    private var currentCallType: CallType?
    private var currentChannel: String?
    private var currentToken: String?
    public var localUser: CallUser?
    public var currentRemoteUser: CallUser?
    
    private var callStartTime: Date?
    private var durationTimer: Timer?
    
    /// 呼叫超时定时器（默认 90 秒）
    private var callingTimeoutTimer: Timer?
    public var callingTimeoutInterval: TimeInterval = 30
    
    // 群组通话用户列表
    private var remoteUsers: [UInt: CallUser] = [:]
    
    // 信令监听器（由 CallManager 实现，并注册到 signalDelegate）
    private let signalListener = CallManagerSignalListener()
    
    private init() {
        engine.delegate = self
        signalListener.manager = self
    }
    
    // MARK: - 声音/震动处理
    
    private let soundService = CallSoundService.shared
    
    /// 根据通话状态变化触发对应的声音和震动
    private func handleSoundForStateChange(from oldState: CallState, to newState: CallState) {
        switch newState {
        case .calling:
            // 主叫发起通话，播放呼叫等待音
            soundService.startOutgoingRingtone()
        case .incoming:
            // 被叫收到来电，播放来电彩铃 + 震动
            soundService.startIncomingRingtone()
        case .connecting:
            // 连接中，停止铃声
            soundService.stopAllSounds()
        case .connected:
            // 通话接通，停止铃声，播放接通提示音
            soundService.stopAllSounds()
            soundService.playCallConnectedSound()
        case .disconnected:
            // 通话挂断，播放挂断提示音
            soundService.playCallEndedSound()
        case .failed:
            // 通话失败，停止所有声音
            soundService.stopAllSounds()
        case .idle:
            // 空闲，确保停止所有声音
            soundService.stopAllSounds()
        default:
            break
        }
    }
    
    // MARK: - 公共方法 - 发起通话
    
    /// 发起单聊通话
    /// - Parameters:
    ///   - user: 被叫用户信息
    ///   - channelName: 频道名
    ///   - callType: 通话类型
    ///   - completion: 完成回调
    public func startCall(to user: CallUser, channelName: String, callType: CallType, completion: ((Result<Void, Error>) -> Void)? = nil) {
        log("发起单聊通话: user=\(user.name)(userId:\(user.userId)), channel=\(channelName), type=\(callType)")
        guard currentState == .idle else {
            log("⚠️ 发起失败: 当前状态不是 idle")
            failWithError("已有通话进行中", completion: completion)
            return
        }
        
        guard let userId = userProvider?.currentUserId else {
            log("⚠️ 发起失败: 无法获取当前用户ID")
            failWithError("无法获取当前用户ID", completion: completion)
            return
        }
        
        isCaller = true
        currentCallType = callType
        currentRemoteUser = user
        currentChannel = channelName
        currentState = .calling
        startCallingTimeout()
        
        // 立即回调 success，让 App 先弹出通话界面
        completion?(.success(()))
        
        // 异步获取 Token、加入频道、发送信令
        tokenProvider?.fetchToken(channelName: channelName, userId: userId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.currentToken = token
                self.log("获取 Token 成功, 加入频道...")
                let success = self.engine.joinChannel(channelName, token: token, uid: UInt(userId) ?? 0, isVideoCall: callType == .video)
                if !success {
                    self.log("⚠️ 加入频道失败 (engine.joinChannel 返回 false)")
                    self.failWithError("加入频道失败")
                    return
                }
                self.signalDelegate?.sendCallRequest(toUserId: user.userId, channelName: channelName, token: token, callType: callType) { result in
                    if case .failure(let error) = result {
                        self.log("⚠️ 发送信令失败: \(error.localizedDescription)")
                        self.failWithError(error.localizedDescription)
                    } else {
                        self.log("发送信令成功")
                    }
                }
            case .failure(let error):
                self.log("⚠️ 获取 Token 失败: \(error.localizedDescription)")
                self.failWithError(error.localizedDescription)
            }
        }
    }
    
    /// 发起群聊通话
    /// - Parameters:
    ///   - channelName: 频道名
    ///   - callType: 通话类型
    ///   - completion: 完成回调
    public func startGroupCall(channelName: String, callType: CallType, completion: ((Result<Void, Error>) -> Void)? = nil) {
        log("发起群聊通话: channel=\(channelName), type=\(callType)")
        guard currentState == .idle else {
            log("⚠️ 发起失败: 当前状态不是 idle")
            completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "已有通话进行中"])))
            return
        }
        
        guard let userId = userProvider?.currentUserId else {
            log("⚠️ 发起失败: 无法获取当前用户ID")
            completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取当前用户ID"])))
            return
        }
        
        isCaller = true
        currentCallType = callType
        currentState = .calling
        currentChannel = channelName
        startCallingTimeout()
        
        // 立即回调 success，让 App 先弹出通话界面
        completion?(.success(()))
        
        // 异步获取 Token、加入频道
        tokenProvider?.fetchToken(channelName: channelName, userId: userId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.currentToken = token
                self.log("获取 Token 成功, 加入频道...")
                let success = self.engine.joinChannel(channelName, token: token, uid: UInt(userId) ?? 0, isVideoCall: callType == .video)
                if success {
                    self.currentState = .connecting
                } else {
                    self.log("⚠️ 加入频道失败 (engine.joinChannel 返回 false)")
                    self.failWithError("加入频道失败")
                }
            case .failure(let error):
                self.log("⚠️ 获取 Token 失败: \(error.localizedDescription)")
                self.failWithError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - 公共方法 - 接听/拒绝/挂断
    
    /// 接听来电（在收到 didReceiveIncomingCall 后调用）
    public func acceptCall() {
        log("接听来电")
        guard currentState == .incoming,
              let channel = currentChannel,
              let callType = currentCallType,
              let remoteUser = currentRemoteUser,
              let userId = userProvider?.currentUserId else {
            log("⚠️ 接听失败: guard 不通过 (state=\(currentState), channel=\(currentChannel ?? "nil"), callType=\(currentCallType), remoteUser=\(currentRemoteUser), userId=\(userProvider?.currentUserId ?? "nil"))")
            return
        }
        
        stopCallingTimeout()
        isCaller = false
        tokenProvider?.fetchToken(channelName: channel, userId: userId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.log("接听: 获取 Token 成功, 加入频道...")
                let success = self.engine.joinChannel(channel, token: token, uid: UInt(userId) ?? 0, isVideoCall: callType == .video)
                if !success {
                    self.log("⚠️ 接听: 加入频道失败")
                    self.failWithError("加入频道失败")
                    return
                }
                self.signalDelegate?.sendAcceptResponse(toUserId: remoteUser.userId) { _ in }
                self.currentState = .connecting
            case .failure(let error):
                self.log("⚠️ 接听: 获取 Token 失败: \(error.localizedDescription)")
                self.failWithError(error.localizedDescription)
            }
        }
    }
    
    /// 拒绝来电
    public func rejectCall() {
        log("拒绝来电")
        guard currentState == .incoming, let remoteUser = currentRemoteUser else {
            log("⚠️ 拒绝失败: guard 不通过 (state=\(currentState), remoteUser=\(currentRemoteUser))")
            return
        }
        stopCallingTimeout()
        signalDelegate?.sendRejectResponse(toUserId: remoteUser.userId, reason: nil) { _ in }
        disconnectCall(error: nil)
    }
    
    /// 挂断当前通话
    public func hangUp() {
        log("挂断通话")
        guard currentState != .idle, currentState != .disconnected else {
            log("⚠️ 挂断忽略: 当前状态=\(currentState)")
            return
        }
        stopCallingTimeout()
        
        if let remoteUser = currentRemoteUser, currentState == .connected || currentState == .reconnecting {
            log("发送挂断信令给 userId=\(remoteUser.userId)")
            signalDelegate?.sendHangupSignal(toUserId: remoteUser.userId) { _ in }
        } else if let remoteUser = currentRemoteUser, currentState == .calling || currentState == .connecting || currentState == .incoming {
            log("发送取消信令给 userId=\(remoteUser.userId)")
            signalDelegate?.sendCancelSignal(toUserId: remoteUser.userId) { _ in }
        }
        
        disconnectCall(error: nil)
    }
    
    // MARK: - 公共方法 - 状态查询
    
    /// 获取当前通话时长（秒）
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
    
    /// 获取当前通话类型
    public var getCurrentCallType: CallType? { currentCallType }
    
    /// 获取当前远程用户（单聊）
    public var getCurrentRemoteUser: CallUser? { currentRemoteUser }
    
    /// 获取群组所有远端用户
    public func getAllRemoteUsers() -> [CallUser] { Array(remoteUsers.values) }
    
    // MARK: - 公共方法 - 音视频控制（转发给引擎）
    public func muteAudio(_ mute: Bool) {
        log("静音音频: \(mute)")
        engine.muteLocalAudio(mute)
        localUser?.isAudioMuted = mute
        DispatchQueue.main.async { [weak self] in
            self?.uiDelegate.localAudioMutedDidChange(mute)
        }
    }
    public func muteVideo(_ mute: Bool) {
        log("静音视频: \(mute)")
        engine.muteLocalVideo(mute)
        localUser?.isVideoMuted = mute
        DispatchQueue.main.async { [weak self] in
            self?.uiDelegate.localVideoMutedDidChange(mute)
        }
    }
    public func setSpeakerEnabled(_ enabled: Bool) { engine.setSpeakerEnabled(enabled) }
    public func switchCamera() { engine.switchCamera() }
    public func setupLocalVideoView(_ view: UIView) { engine.setupLocalVideoView(view) }
    public func setupRemoteVideoView(_ view: UIView, forUid uid: UInt) { engine.setupRemoteVideoView(view, forUid: uid) }
    public func startPreview() { engine.startPreview() }
    public func stopPreview() { engine.stopPreview() }
    
    // MARK: - 信令接收（由 App 层信令模块调用）
    
    /// 收到单聊来电
    public func receiveIncomingCall(from user: CallUser, channelName: String, token: String, callType: CallType) {
        log("收到来电: from=\(user.name)(userId:\(user.userId)), channel=\(channelName), type=\(callType)")
        guard user.userId != userProvider?.currentUserId else {
            log("⚠️ 来电忽略: 是自己")
            return
        }
        guard currentState == .idle else {
            // 非空闲状态：判断是否同一通话房间
            if currentChannel == channelName {
                // 同一房间的重复推送（Socket 和接口都推了），通知 App 弹 Toast
                log("同一通话重复推送: channel=\(channelName)，通知 App")
                DispatchQueue.main.async { [weak self] in
                    self?.uiDelegate.didReceiveDuplicateIncomingCall(from: user, callType: callType, channelName: channelName)
                }
            } else {
                // 不同房间的来电，自动拒绝
                log("⚠️ 来电忙碌: 当前状态=\(currentState), 不同房间，自动拒绝")
                signalDelegate?.sendRejectResponse(toUserId: user.userId, reason: "busy") { _ in }
            }
            return
        }
        
        isCaller = false
        currentState = .incoming
        currentCallType = callType
        currentChannel = channelName
        currentRemoteUser = user
        currentToken = token
        startCallingTimeout()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 通知 uiDelegate 展示来电界面（由 App 层的 AppCallUIDelegate 处理弹窗和 VC present）
            self.uiDelegate.didReceiveIncomingCall(from: user, callType: callType, channelName: channelName, token: token)
        }
    }
    
    /// 对方接受通话
    public func onCallAccepted(fromUserId: String) {
        log("对方接受: fromUserId=\(fromUserId)")
        guard currentState == .calling || currentState == .connecting else {
            log("⚠️ 接受忽略: 当前状态=\(currentState)")
            return
        }
        // 单聊场景：只要不是自己发的就处理（userId 可能因 App 端数据源不同而不匹配）
        if currentRemoteUser?.userId != fromUserId {
            log("⚠️ userId 不匹配 (remoteUserId=\(currentRemoteUser?.userId ?? "nil"), fromUserId=\(fromUserId))，但仍处理")
        }
        stopCallingTimeout()
        currentState = .connecting
    }
    
    /// 对方拒绝通话
    public func onCallRejected(fromUserId: String, reason: String?) {
        log("对方拒绝: fromUserId=\(fromUserId), reason=\(reason ?? "nil")")
        // 允许从 calling/connecting/connected 状态拒绝（对方可能先加入频道再拒绝）
        guard currentState == .calling || currentState == .connecting || currentState == .connected else {
            log("⚠️ 拒绝忽略: 当前状态=\(currentState)")
            return
        }
        // 单聊场景：只要不是自己发的就处理
        if currentRemoteUser?.userId != fromUserId {
            log("⚠️ userId 不匹配 (remoteUserId=\(currentRemoteUser?.userId ?? "nil"), fromUserId=\(fromUserId))，但仍处理")
        }
        stopCallingTimeout()
        disconnectCall(error: nil)
    }
    
    /// 对方挂断
    public func onCallHangup(fromUserId: String) {
        log("对方挂断: fromUserId=\(fromUserId)")
        guard currentState != .idle && currentState != .disconnected else {
            log("⚠️ 挂断忽略: 当前状态=\(currentState)")
            return
        }
        // 单聊场景：只要不是自己发的就处理
        if currentRemoteUser?.userId != fromUserId {
            log("⚠️ userId 不匹配 (remoteUserId=\(currentRemoteUser?.userId ?? "nil"), fromUserId=\(fromUserId))，但仍处理")
        }
        stopCallingTimeout()
        disconnectCall(error: nil)
    }
    
    /// 对方取消通话
    public func onCallCanceled(fromUserId: String) {
        log("对方取消: fromUserId=\(fromUserId)")
        guard currentState == .incoming || currentState == .calling else {
            log("⚠️ 取消忽略: 当前状态=\(currentState)")
            return
        }
        // 单聊场景：只要不是自己发的就处理
        if currentRemoteUser?.userId != fromUserId {
            log("⚠️ userId 不匹配 (remoteUserId=\(currentRemoteUser?.userId ?? "nil"), fromUserId=\(fromUserId))，但仍处理")
        }
        stopCallingTimeout()
        disconnectCall(error: nil)
    }
    
    // MARK: - 内部方法
    
    /// 统一的通话断开处理：先设置 disconnected/failed 状态通知 UI，延迟后再清理资源回 idle
    private func disconnectCall(error: Error?) {
        log("disconnectCall: error=\(error?.localizedDescription ?? "nil")")
        guard currentState != .disconnected && currentState != .failed && currentState != .idle else {
            log("disconnectCall 忽略: 已是终态 \(currentState)")
            return
        }
        let targetState: CallState = (error != nil) ? .failed : .disconnected
        currentState = targetState
        let notify = {
            self.log("通知 uiDelegate.didDisconnect")
            self.uiDelegate.didDisconnect(error: error)
            // 延迟 resetCall，让 UI 有时间展示 disconnected/failed 状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.log("延迟 resetCall")
                self?.resetCall()
            }
        }
        if Thread.isMainThread {
            notify()
        } else {
            DispatchQueue.main.async { notify() }
        }
    }
    
    private func failWithError(_ message: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        log("⚠️ failWithError: \(message)")
        let error = NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        stopCallingTimeout()
        // 统一走 disconnectCall，避免 didDisconnect 重复调用
        disconnectCall(error: error)
        DispatchQueue.main.async { [weak self] in
            self?.uiDelegate.didOccurError(error)
        }
        completion?(.failure(error))
    }
    
    private func resetCall() {
        log("resetCall: 清理所有资源，状态回 idle")
        stopDurationTimer()
        stopCallingTimeout()
        // 停止所有声音和震动
        soundService.stopAllSounds()
        // 隐藏来电弹窗（可能在超时等场景下还没关闭）
        IncomingCallManager.shared.hide()
        // 统一清理：离开频道、悬浮窗、画中画（必须在重置 currentCallType 之前）
        cleanupAllResources()
        isCaller = false
        currentState = .idle
        currentCallType = nil
        currentChannel = nil
        currentRemoteUser = nil
        currentToken = nil
        localUser = nil
        callStartTime = nil
        remoteUsers.removeAll()
    }
    
    /// 统一清理所有通话资源（离开频道、悬浮窗、画中画）
    private func cleanupAllResources() {
        log("cleanupAllResources: callType=\(currentCallType?.rawValue ?? "nil")")
        // 离开频道，停止音视频流
        engine.leaveChannel()
        // 停止视频预览
        if currentCallType == .video {
            engine.stopPreview()
        }
        // 隐藏悬浮窗
        if FloatingWindowManager.shared.isShowing() {
            FloatingWindowManager.shared.hideFloatingWindow()
        }
        // 关闭画中画
        if currentCallType == .video {
            engine.stopPiPCapturer()
            PictureInPictureManager.shared.endCall()
        }
    }
    
    private func startDurationTimer() {
        stopDurationTimer()
        log("启动通话计时器")
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.callStartTime else { return }
            let duration = Date().timeIntervalSince(start)
            self.uiDelegate.didUpdateDuration(duration)
        }
        RunLoop.main.add(durationTimer!, forMode: .common)
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // MARK: - 呼叫超时
    
    private func startCallingTimeout() {
        stopCallingTimeout()
        log("启动呼叫超时定时器: \(callingTimeoutInterval)s")
        callingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: callingTimeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.currentState == .calling || self.currentState == .incoming || self.currentState == .connecting {
                self.log("⚠️ 呼叫超时! 通知 App 端处理")
                self.stopCallingTimeout()
                DispatchQueue.main.async {
                    self.uiDelegate.didCallTimeout()
                }
            }
        }
        RunLoop.main.add(callingTimeoutTimer!, forMode: .common)
    }
    
    private func stopCallingTimeout() {
        callingTimeoutTimer?.invalidate()
        callingTimeoutTimer = nil
    }
}

// MARK: - CallSignalListener 实现（内部类）
private class CallManagerSignalListener: CallSignalListener {
    weak var manager: CallManager?
    
    func onReceiveCall(fromUserId: String, channelName: String, token: String, callType: CallType) {
        let user = CallUser(userId: fromUserId, name: fromUserId)
        manager?.receiveIncomingCall(from: user, channelName: channelName, token: token, callType: callType)
    }
    func onCallAccepted(fromUserId: String) { manager?.onCallAccepted(fromUserId: fromUserId) }
    func onCallRejected(fromUserId: String, reason: String?) { manager?.onCallRejected(fromUserId: fromUserId, reason: reason) }
    func onCallHangup(fromUserId: String) { manager?.onCallHangup(fromUserId: fromUserId) }
    func onCallCanceled(fromUserId: String) { manager?.onCallCanceled(fromUserId: fromUserId) }
}

// MARK: - AgoraEngineDelegate
extension CallManager: AgoraEngineDelegate {
    public func engine(_ engine: AgoraEngineManager, didJoinChannel channel: String, uid: UInt) {
        log("引擎回调: 本地加入频道 channel=\(channel), uid=\(uid)")
        let localName = userProvider?.currentUserName ?? userProvider?.currentUserId ?? "\(uid)"
        let localUserId = userProvider?.currentUserId ?? "\(uid)"
        localUser = CallUser(userId: localUserId, uid: uid, name: localName, isLocal: true)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let localUser = self.localUser else { return }
            self.uiDelegate.didJoinChannel(withUser: localUser)
        }
        // 本地加入频道只更新状态，不开始计时
        // 计时在远端用户加入时开始
        if currentState == .calling || currentState == .incoming {
            currentState = .connecting
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, didLeaveChannel channel: String) {
        log("引擎回调: 本地离开频道 channel=\(channel)")
    }
    
    public func engine(_ engine: AgoraEngineManager, didJoinedOfUid uid: UInt) {
        log("引擎回调: 远端用户加入 uid=\(uid)")
        // 远端用户加入
        stopCallingTimeout()
        
        // 如果还没有进入 connected 状态，推进状态
        if currentState == .connecting || currentState == .calling || currentState == .incoming {
            currentState = .connected
            if callStartTime == nil {
                callStartTime = Date()
                startDurationTimer()
            }
        }
        
        if let remoteUser = currentRemoteUser, remoteUser.uid == 0 {
            var updatedUser = remoteUser
            updatedUser.uid = uid
            currentRemoteUser = updatedUser
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidJoin(updatedUser)
            }
        } else if let remoteUser = currentRemoteUser, remoteUser.uid == uid {
            // 已有远端用户信息（uid 已更新），直接通知
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidJoin(remoteUser)
            }
        } else {
            let user = CallUser(userId: "\(uid)", uid: uid, name: "user_\(uid)")
            remoteUsers[uid] = user
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidJoin(user)
            }
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, didOfflineOfUid uid: UInt) {
        log("引擎回调: 远端用户离开 uid=\(uid)")
        if let user = remoteUsers[uid] {
            remoteUsers.removeValue(forKey: uid)
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidLeave(user)
            }
        } else if let remoteUser = currentRemoteUser, remoteUser.uid == uid {
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidLeave(remoteUser)
            }
            // 单聊：远端用户离开即结束通话（无论当前状态）
            if currentState != .idle && currentState != .disconnected {
                log("远端用户离开，触发 hangUp")
                hangUp()
            }
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, didOccurError error: Error) {
        log("⚠️ 引擎回调: 发生错误: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.uiDelegate.didOccurError(error)
            self?.disconnectCall(error: error)
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, localVideoMuted muted: Bool) {
        log("引擎回调: 本地视频静音 muted=\(muted)")
        localUser?.isVideoMuted = muted
        DispatchQueue.main.async { [weak self] in
            self?.uiDelegate.localVideoMutedDidChange(muted)
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, localAudioMuted muted: Bool) {
        log("引擎回调: 本地音频静音 muted=\(muted)")
        localUser?.isAudioMuted = muted
        DispatchQueue.main.async { [weak self] in
            self?.uiDelegate.localAudioMutedDidChange(muted)
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, remoteVideoMuted muted: Bool, ofUid uid: UInt) {
        log("引擎回调: 远端视频静音 muted=\(muted), uid=\(uid)")
        if var user = remoteUsers[uid] {
            user.isVideoMuted = muted
            remoteUsers[uid] = user
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidToggleVideo(user, muted: muted)
            }
        } else if var remoteUser = currentRemoteUser, remoteUser.uid == uid {
            remoteUser.isVideoMuted = muted
            currentRemoteUser = remoteUser
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidToggleVideo(remoteUser, muted: muted)
            }
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, remoteAudioMuted muted: Bool, ofUid uid: UInt) {
        log("引擎回调: 远端音频静音 muted=\(muted), uid=\(uid)")
        if var user = remoteUsers[uid] {
            user.isAudioMuted = muted
            remoteUsers[uid] = user
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidToggleAudio(user, muted: muted)
            }
        } else if var remoteUser = currentRemoteUser, remoteUser.uid == uid {
            remoteUser.isAudioMuted = muted
            currentRemoteUser = remoteUser
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidToggleAudio(remoteUser, muted: muted)
            }
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, connectionStateChanged state: AgoraConnectionState) {
        log("引擎回调: 连接状态变化 state=\(state.rawValue)")
        switch state {
        case .connecting:
            if currentState == .calling || currentState == .incoming {
                currentState = .connecting
            }
        case .connected:
            // 引擎连接成功，推进到 .connecting（.connected 只在远端用户加入时才设置）
            if currentState == .calling || currentState == .incoming {
                currentState = .connecting
            }
        case .reconnecting:
            if currentState == .connected {
                currentState = .reconnecting
            }
        case .disconnected:
            if currentState == .connected || currentState == .reconnecting || currentState == .connecting {
                log("引擎连接断开，触发 disconnectCall")
                disconnectCall(error: nil)
            }
        default:
            break
        }
    }
}
