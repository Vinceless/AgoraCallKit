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
    
    // MARK: - 线程安全
    /// 保护所有状态属性读写的锁，RTC 引擎回调（非主线程）和主线程用户操作
    private let stateLock = NSLock()
    
    // MARK: - 内部状态
    
    /// 是否主叫方。仅从主线程写入，不需要锁保护
    public private(set) var isCaller: Bool = false
    
    /// 当前通话状态的锁保护 backing store
    private var _currentState: CallState = .idle
    
    /// 当前通话状态（线程安全）
    public var currentState: CallState {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _currentState
        }
        set {
            stateLock.lock()
            let oldValue = _currentState
            _currentState = newValue
            stateLock.unlock()
            guard oldValue != newValue else { return }
            // didSet 逻辑：锁外执行，避免死锁
            log("状态变化: \(oldValue) → \(newValue)")
            handleSoundForStateChange(from: oldValue, to: newValue)
            if Thread.isMainThread {
                uiDelegate.callStateDidChange(newValue)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.uiDelegate.callStateDidChange(newValue)
                }
            }
        }
    }
    
    /// 原子地执行状态转换：仅当当前状态等于 expected 时才切换到 newState。
    /// - Returns: true 表示转换成功，false 表示当前状态不匹配 expected
    private func transitionState(from expected: CallState, to newState: CallState) -> Bool {
        stateLock.lock()
        let oldValue = _currentState
        guard oldValue == expected else {
            stateLock.unlock()
            return false
        }
        _currentState = newState
        stateLock.unlock()
        // didSet 逻辑在锁外执行
        if oldValue != newState {
            log("状态变化: \(oldValue) → \(newState)")
            handleSoundForStateChange(from: oldValue, to: newState)
            if Thread.isMainThread {
                uiDelegate.callStateDidChange(newState)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.uiDelegate.callStateDidChange(newState)
                }
            }
        }
        return true
    }
    
    /// 锁保护地设置状态（无前置条件检查），返回旧值
    private func setStateUnconditionally(_ newState: CallState) -> CallState {
        stateLock.lock()
        let oldValue = _currentState
        _currentState = newState
        stateLock.unlock()
        guard oldValue != newState else { return oldValue }
        log("状态变化: \(oldValue) → \(newState)")
        handleSoundForStateChange(from: oldValue, to: newState)
        if Thread.isMainThread {
            uiDelegate.callStateDidChange(newState)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.callStateDidChange(newState)
            }
        }
        return oldValue
    }
    
    private var currentCallType: CallType?
    private var currentChannel: String?
    private var currentToken: String?
    
    /// CallKit/LiveCommunicationKit 使用的 UUID（用于系统来电界面）
    private var currentCallUUID: UUID?
    
    /// 服务端返回的通话标识符（用于信令关联）
    public private(set) var currentCallID: String?
    
    public var localUser: CallUser?
    public var currentRemoteUser: CallUser?
    
    private var callStartTime: Date?
    private var durationTimer: Timer?
    
    /// 呼叫超时定时器（默认 90 秒）
    private var callingTimeoutTimer: Timer?
    public var callingTimeoutInterval: TimeInterval = 30
    
    // 群组通话用户列表
    private var remoteUsers: [UInt: CallUser] = [:]
    
    private var hasReportedConnected = false
    
    /// 用户是否通过系统来电界面（CallKit/LiveCommunicationKit）点击了接听
    private var hasAcceptedViaSystemUI = false
    
    // 信令监听器（由 CallManager 实现，并注册到 signalDelegate）
    private let signalListener = CallManagerSignalListener()
    
    private init() {
        engine.delegate = self
        signalListener.manager = self
        
        // 配置 LiveCommunicationKit（iOS 17.4+ 且已启用）
        if #available(iOS 17.4, *) {
            LiveCommunicationKitManager.shared.delegate = self
            LiveCommunicationKitManager.shared.configure()
            print("[CallManager] LiveCommunicationKit 已启用（iOS 17.4+）")
        }
        #if DEBUG
        CallKitManager.shared.delegate = self
        // 根据 CallConfiguration 自动配置 CallKit
        CallKitManager.shared.configure()
        #endif
        // 注册 App 进入前台通知，关闭系统来电界面并显示自定义来电界面
        registerAppLifecycleObserver()
    }
    
    // MARK: - App 生命周期监听
    
    /// 注册 App 进入前台通知
    private func registerAppLifecycleObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        log("已注册 App 进入前台通知")
    }
    
    /// App 进入前台时调用：关闭系统来电界面，根据接听状态显示对应界面
    @objc private func handleAppDidBecomeActive() {
        log("App 进入前台, currentState=\(currentState), hasAcceptedViaSystemUI=\(hasAcceptedViaSystemUI)")
        
        // 如果用户已在系统界面接听（hasAcceptedViaSystemUI=true），需要：
        // 1. 关闭系统来电界面
        // 2. present 通话控制器
        // 即使状态已经变为 connecting/incoming 之后被接听，也要处理
        let needsDismissSystemUI = hasAcceptedViaSystemUI || currentState == .incoming
        
        guard needsDismissSystemUI,
              let remoteUser = currentRemoteUser,
              let callType = currentCallType else {
            log("App 进入前台：无需处理（状态已变化且用户未在系统界面接听）")
            return
        }
        
        // 1. 关闭系统来电界面（CallKit 或 LiveCommunicationKit）
        log("App 进入前台: useLiveCommunicationKit=\(useLiveCommunicationKit),")
        if useLiveCommunicationKit {
            if #available(iOS 17.4, *) {
                log("App 进入前台: 关闭 LiveCommunicationKit 来电界面")
                LiveCommunicationKitManager.shared.dismissIncomingCallUI()
            }
        }
#if DEBUG
        if useSystemCallUI {
            log("App 进入前台: 关闭 CallKit 来电界面, hasAcceptedViaSystemUI=\(hasAcceptedViaSystemUI)")
            CallKitManager.shared.dismissIncomingCallUI(hasUserAccepted: hasAcceptedViaSystemUI)
        }
#endif
        
        // 2. 根据是否已在系统界面接听，决定显示来电弹窗还是聊天控制器
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.hasAcceptedViaSystemUI {
                // 用户已在系统来电界面点击了接听 → 显示聊天控制器
                log("App 进入前台：用户已在系统界面接听，显示聊天控制器")
                self.uiDelegate.didAcceptIncomingCall(from: remoteUser, callType: callType)
            } else {
                // 用户还未接听 → 显示来电弹窗
                if let channel = self.currentChannel,
                   let token = self.currentToken {
                    log("App 进入前台：用户未接听，显示来电弹窗")
                    self.uiDelegate.didShowIncomingCallUIAfterForeground(
                        from: remoteUser,
                        callType: callType,
                        channelName: channel,
                        token: token
                    )
                }
            }
        }
    }
    
    // MARK: - 通话框架选择
    #if DEBUG
    /// 是否使用系统来电界面（CallKit 或 LiveCommunicationKit）
    /// - 注意：isCallKitEnabled = false 时完全不使用系统来电界面
    /// - isCallKitEnabled = true 时：
    ///   - iOS 17.4+ && isLiveCommunicationKitEnabled = true → LiveCommunicationKit
    ///   - 其他情况 → CallKit
    private var useSystemCallUI: Bool {
        return CallConfiguration.shared.isCallKitEnabled
    }
    #endif
    /// 是否使用 LiveCommunicationKit（iOS 17.4+ 且已启用）
    /// - 注意：只要 isLiveCommunicationKitEnabled = true，iOS 17.4+ 就使用 LiveCommunicationKit
    /// - isCallKitEnabled 仅在 LiveCommunicationKit 不可用时作为 CallKit 的开关
    private var useLiveCommunicationKit: Bool {
        if #available(iOS 17.4, *) {
            return CallConfiguration.shared.isLiveCommunicationKitEnabled
        }
        return false
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
            // 通话接通：标记 bypassAudioSession，防止后续声音操作覆盖 Agora 音频会话
            soundService.bypassAudioSession = true
            soundService.stopAllSounds()
            soundService.playCallConnectedSound()
        case .disconnected:
            // 通话挂断：恢复音频会话可控，播放挂断提示音
            soundService.bypassAudioSession = false
            soundService.stopAllSounds()
            soundService.playCallEndedSound()
        case .failed:
            // 通话失败，停止所有声音
            soundService.bypassAudioSession = false
            soundService.stopAllSounds()
        case .idle:
            // 空闲，确保停止所有声音并重置 bypass
            soundService.bypassAudioSession = false
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
    ///   - callID: 服务端返回的通话标识符（用于后续信令关联）
    ///   - token: 可选 token，如果不为 nil 且非空字符串则直接使用，否则通过 tokenProvider 获取
    ///   - completion: 完成回调
    public func startCall(to user: CallUser, channelName: String, callType: CallType, callID: String? = nil, token: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        log("发起单聊通话: user=\(user.name)(userId:\(user.userId)), channel=\(channelName), type=\(callType), callID=\(callID ?? "nil"), hasDirectToken=\(token != nil && !token!.isEmpty)")
        
        guard let userId = userProvider?.currentUserId else {
            log("⚠️ 发起失败: 无法获取当前用户ID")
            failWithError("无法获取当前用户ID", completion: completion)
            return
        }
        
        // 原子地检查 idle 并切换到 calling，防止竞态
        guard transitionState(from: .idle, to: .calling) else {
            log("⚠️ 发起失败: 当前状态不是 idle")
            failWithError("已有通话进行中", completion: completion)
            return
        }
        
        isCaller = true
        currentCallType = callType
        currentRemoteUser = user
        currentChannel = channelName
        currentCallID = callID
        startCallingTimeout()
        
        // 立即回调 success，让 App 先弹出通话界面
        completion?(.success(()))
        
        // 异步获取 Token、加入频道、发送信令
        joinChannelWithToken(channelName: channelName, userId: userId, callType: callType, directToken: token) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.currentToken = token
                let effectiveCallID = self.currentCallID ?? ""
                self.signalDelegate?.sendCallRequest(callID: effectiveCallID, toUserId: user.userId, channelName: channelName, token: token, callType: callType) { result in
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
    ///   - token: 可选 token，如果不为 nil 且非空字符串则直接使用，否则通过 tokenProvider 获取
    ///   - completion: 完成回调
    public func startGroupCall(channelName: String, callType: CallType, token: String? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        log("发起群聊通话: channel=\(channelName), type=\(callType), hasDirectToken=\(token != nil && !token!.isEmpty)")
        
        guard let userId = userProvider?.currentUserId else {
            log("⚠️ 发起失败: 无法获取当前用户ID")
            completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取当前用户ID"])))
            return
        }
        
        // 原子地检查 idle 并切换到 calling
        guard transitionState(from: .idle, to: .calling) else {
            log("⚠️ 发起失败: 当前状态不是 idle")
            completion?(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "已有通话进行中"])))
            return
        }
        
        isCaller = true
        currentCallType = callType
        currentChannel = channelName
        startCallingTimeout()
        
        // 立即回调 success，让 App 先弹出通话界面
        completion?(.success(()))
        
        // 异步获取 Token、加入频道
        joinChannelWithToken(channelName: channelName, userId: userId, callType: callType, directToken: token) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.currentToken = token
            case .failure(let error):
                self.log("⚠️ 获取 Token 失败: \(error.localizedDescription)")
                self.failWithError(error.localizedDescription)
            }
        }
    }
    
    // MARK: - 公共方法 - 接听/拒绝/挂断
    
    /// 接听来电（在收到 didReceiveIncomingCall 后调用）
    /// - Parameter skipPresentUI: 是否跳过 present 控制器（当 App 层已自行 present 时传 true）
    /// - Parameter token: 可选 token，如果不为 nil 且非空字符串则直接使用，否则通过 tokenProvider 获取
    public func acceptCall(skipPresentUI: Bool = false, token: String? = nil, completion: ((Bool) -> Void)? = nil) {
        log("接听来电, skipPresentUI=\(skipPresentUI), hasDirectToken=\(token != nil && !token!.isEmpty), currentState=\(currentState), callID=\(currentCallID ?? "nil")")
        guard currentState == .incoming,
              let channel = currentChannel,
              let callType = currentCallType,
              let remoteUser = currentRemoteUser,
              let userId = userProvider?.currentUserId else {
            log("⚠️ 接听失败: guard 不通过 (state=\(currentState), channel=\(currentChannel ?? "nil"), callType=\(currentCallType), remoteUser=\(currentRemoteUser), userId=\(userProvider?.currentUserId ?? "nil"))")
            completion?(false)
            return
        }
        
        stopCallingTimeout()
        isCaller = false
        joinChannelWithToken(channelName: channel, userId: userId, callType: callType, directToken: token) { [weak self] result in
            guard let self = self else {
                completion?(false)
                return
            }
            switch result {
            case .success:
                // 原子切换状态：防止异步间隙中远端已取消导致状态不一致
                guard self.transitionState(from: .incoming, to: .connecting) else {
                    self.log("⚠️ 接听: 状态已变化（异步间隙中远端取消等），放弃切换")
                    completion?(false)
                    return
                }
                let effectiveCallID = self.currentCallID ?? ""
                self.signalDelegate?.sendAcceptResponse(callID: effectiveCallID, toUserId: remoteUser.userId) { _ in }

                // ========== 通知 CallKit/LiveCommunicationKit 停止来电界面 ==========
                // 当用户在 App 内点击"接受"时，需要通知系统来电界面通话已接听
                if self.useLiveCommunicationKit {
                    if #available(iOS 17.4, *) {
                        LiveCommunicationKitManager.shared.markCallAccepted()
                    }
                }
#if DEBUG
                if self.useSystemCallUI {
                    CallKitManager.shared.markCallAccepted()
                }
                #endif
                // ========== 通知 App 层 present 通话控制器（除非已跳过） ==========
                if !skipPresentUI {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.uiDelegate.didAcceptIncomingCall(from: remoteUser, callType: callType)
                    }
                } else {
                    self.log("接听: skipPresentUI=true，跳过 present 控制器")
                }
                
                completion?(true)
            case .failure(let error):
                self.log("⚠️ 接听: 获取 Token 失败: \(error.localizedDescription)")
                self.failWithError(error.localizedDescription)
                completion?(false)
            }
        }
    }
    
    /// 拒绝来电
    public func rejectCall() {
        log("拒绝来电, callID=\(currentCallID ?? "nil")")
        guard currentState == .incoming, let remoteUser = currentRemoteUser else {
            log("⚠️ 拒绝失败: guard 不通过 (state=\(currentState), remoteUser=\(currentRemoteUser))")
            return
        }
        stopCallingTimeout()
        let effectiveCallID = currentCallID ?? ""
        signalDelegate?.sendRejectResponse(callID: effectiveCallID, toUserId: remoteUser.userId, reason: nil) { _ in }
        disconnectCall(error: nil)
    }
    
    /// 挂断当前通话
    public func hangUp() {
        log("挂断通话, callID=\(currentCallID ?? "nil")")
        guard currentState != .idle, currentState != .disconnected else {
            log("⚠️ 挂断忽略: 当前状态=\(currentState)")
            return
        }
        stopCallingTimeout()
        
        let effectiveCallID = currentCallID ?? ""
        
        if let remoteUser = currentRemoteUser, currentState == .connected || currentState == .reconnecting {
            log("发送挂断信令给 userId=\(remoteUser.userId), callID=\(effectiveCallID)")
            signalDelegate?.sendHangupSignal(callID: effectiveCallID, toUserId: remoteUser.userId) { _ in }
        } else if let remoteUser = currentRemoteUser, currentState == .calling || currentState == .connecting || currentState == .incoming {
            log("发送取消信令给 userId=\(remoteUser.userId), callID=\(effectiveCallID)")
            signalDelegate?.sendCancelSignal(callID: effectiveCallID, toUserId: remoteUser.userId) { _ in }
        }
        
        disconnectCall(error: nil, endedReason: .remoteEnded)
    }
    
    // MARK: - 公共方法 - 内部辅助

    /// 使用 token 加入频道的统一处理逻辑
    /// - Parameters:
    ///   - channelName: 频道名
    ///   - userId: 用户 ID
    ///   - callType: 通话类型
    ///   - directToken: 可选直接传入的 token，如果不为 nil 且非空字符串则直接使用
    ///   - completion: 完成回调，返回实际使用的 token 或错误
    private func joinChannelWithToken(channelName: String, userId: String, callType: CallType, directToken: String?, completion: @escaping (Result<String, Error>) -> Void) {
        // 如果传入了有效的 token，直接使用
        if let token = directToken, !token.isEmpty {
            self.log("使用直接传入的 Token, 加入频道...")
            let success = engine.joinChannel(channelName, token: token, uid: UInt(userId) ?? 0, isVideoCall: callType == .video)
            if !success {
                self.log("⚠️ 加入频道失败 (engine.joinChannel 返回 false)")
                completion(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "加入频道失败"])))
                return
            }
            completion(.success(token))
            return
        }

        // 否则通过 tokenProvider 获取
        tokenProvider?.fetchToken(channelName: channelName, userId: userId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let token):
                self.log("通过 tokenProvider 获取 Token 成功, 加入频道...")
                let success = self.engine.joinChannel(channelName, token: token, uid: UInt(userId) ?? 0, isVideoCall: callType == .video)
                if !success {
                    self.log("⚠️ 加入频道失败 (engine.joinChannel 返回 false)")
                    completion(.failure(NSError(domain: "CallManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "加入频道失败"])))
                    return
                }
                completion(.success(token))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
    
    /// 获取群组所有远端用户（线程安全快照）
    public func getAllRemoteUsers() -> [CallUser] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return Array(remoteUsers.values)
    }
    
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
    
    /// 收到单聊来电（不带系统UI完成回调，用于非VoIP推送场景）
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - user: 来电用户信息
    ///   - channelName: 频道名
    ///   - token: 声网 Token
    ///   - callType: 通话类型
    ///   - incomingType: 来电类型
    public func receiveIncomingCall(callID: String? = nil, from user: CallUser, channelName: String, token: String, callType: CallType, incomingType: IncomingCallType = .normal) {
        receiveIncomingCall(callID: callID, from: user, channelName: channelName, token: token, callType: callType, incomingType: incomingType, systemUICompletion: { _ in })
    }
    
    /// 收到单聊来电
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - user: 来电用户信息
    ///   - channelName: 频道名
    ///   - token: 声网 Token
    ///   - callType: 通话类型
    ///   - incomingType: 来电类型
    ///   - systemUICompletion: 系统来电界面完成回调
    public func receiveIncomingCall(callID: String? = nil, from user: CallUser, channelName: String, token: String, callType: CallType, incomingType: IncomingCallType = .normal, systemUICompletion: @escaping (Bool) -> Void) {
        log("收到来电: from=\(user.name)(userId:\(user.userId)), channel=\(channelName), type=\(callType), callID=\(callID ?? "nil")")
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
                if let callID = callID {
                    signalDelegate?.sendRejectResponse(callID: callID, toUserId: user.userId, reason: "busy") { _ in }
                }
            }
            return
        }
        
        isCaller = false
        currentCallID = callID  // 缓存服务端 callID
        currentState = .incoming
        currentCallType = callType
        currentChannel = channelName
        currentRemoteUser = user
        currentToken = token
        startCallingTimeout()
        
        let callUUID = UUID()
        currentCallUUID = callUUID
        
        let displayType = CallConfiguration.shared.displayType(for: incomingType)
        
        switch displayType {
        case .liveCommunicationKit:
            if #available(iOS 17.4, *) {
                LiveCommunicationKitManager.shared.reportIncomingCall(
                    uuid: callUUID,
                    callerName: user.name,
                    isVideo: callType == .video,
                    completion: systemUICompletion
                )
                return
            }
        case .callKit:
#if DEBUG
            CallKitManager.shared.reportIncomingCall(
                uuid: callUUID,
                handle: user.userId,
                callerName: user.name,
                isVideo: callType == .video,
                completion: systemUICompletion
            )
#else
            systemUICompletion(true) // 无系统界面，直接认为成功
            #endif
            return
        default:
            systemUICompletion(true) // 无系统界面，直接认为成功
        }
        
        /// 没调用那两个，就调用普通界面
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 通知 uiDelegate 展示来电界面（由 App 层的 AppCallUIDelegate 处理弹窗和 VC present）
            self.uiDelegate.didReceiveIncomingCall(from: user, callType: callType, channelName: channelName, token: token)
        }
    }
    
    /// 对方接受通话
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 接受方用户ID
    public func onCallAccepted(callID: String, fromUserId: String) {
        log("对方接受: callID=\(callID), fromUserId=\(fromUserId)")
        guard currentState == .calling || currentState == .connecting else {
            log("⚠️ 接受忽略: 当前状态=\(currentState)")
            return
        }
        // 单聊场景：只要不是自己发的就处理（userId 可能因 App 端数据源不同而不匹配）
        if currentRemoteUser?.userId != fromUserId {
            log("⚠️ userId 不匹配 (remoteUserId=\(currentRemoteUser?.userId ?? "nil"), fromUserId=\(fromUserId))，但仍处理")
        }
        // 更新 callID（如果之前为空）
        if currentCallID == nil {
            currentCallID = callID
        }
        stopCallingTimeout()
        currentState = .connecting
    }
    
    /// 对方拒绝通话
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 拒绝方用户ID
    ///   - reason: 拒绝原因
    public func onCallRejected(callID: String, fromUserId: String, reason: String?) {
        log("对方拒绝: callID=\(callID), fromUserId=\(fromUserId), reason=\(reason ?? "nil")")
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
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 挂断方用户ID
    public func onCallHangup(callID: String, fromUserId: String) {
        log("对方挂断: callID=\(callID), fromUserId=\(fromUserId)")
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
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 取消方用户ID
    public func onCallCanceled(callID: String, fromUserId: String) {
        log("对方取消: callID=\(callID), fromUserId=\(fromUserId)")
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
    
    /// 呼叫对方失败
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 呼叫失败用户ID
    public func onCallFailed(callID: String, fromUserId: String, reason: String?) {
        log("对方呼叫失败: fromUserId=\(fromUserId), reason=\(reason ?? "未知原因")")
        guard currentState != .idle && currentState != .disconnected && currentState != .failed else {
            log("⚠️ 呼叫失败忽略: 当前状态=\(currentState)")
            return
        }
        // 单聊场景：只要不是自己发的就处理
        if currentRemoteUser?.userId != fromUserId {
            log("⚠️ userId 不匹配 (remoteUserId=\(currentRemoteUser?.userId ?? "nil"), fromUserId=\(fromUserId))，但仍处理")
        }
        stopCallingTimeout()
        let error = NSError(domain: "CallManager", code: -2, userInfo: [NSLocalizedDescriptionKey: reason ?? "呼叫失败"])
        disconnectCall(error: error)
    }
    
    // MARK: - 内部方法
    
    /// 统一的通话断开处理：原子检查状态 + 设置 disconnected/failed，防止多线程重复进入
    private func disconnectCall(error: Error?, endedReason: CallEndedReason = .remoteEnded) {
        log("disconnectCall: error=\(error?.localizedDescription ?? "nil"), reason=\(endedReason)")
        
        let targetState: CallState = (error != nil) ? .failed : .disconnected
        
        // 原子地检查并设置状态：阻止两个线程同时进入 disconnectCall
        stateLock.lock()
        guard _currentState != .disconnected && _currentState != .failed && _currentState != .idle else {
            log("disconnectCall 忽略: 已是终态 \(_currentState)")
            stateLock.unlock()
            return
        }
        let oldState = _currentState
        _currentState = targetState
        stateLock.unlock()
        
        // 状态变更的 didSet 逻辑（锁外执行）
        if oldState != targetState {
            log("状态变化: \(oldState) → \(targetState)")
            handleSoundForStateChange(from: oldState, to: targetState)
            if Thread.isMainThread {
                uiDelegate.callStateDidChange(targetState)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.uiDelegate.callStateDidChange(targetState)
                }
            }
        }
        
        // 通知系统通话结束（锁外执行，避免与系统框架回调产生死锁）
        if useLiveCommunicationKit {
            if #available(iOS 17.4, *) {
                LiveCommunicationKitManager.shared.reportCallEnded(reason: error != nil ? "failed" : "ended")
            }
        }
        #if DEBUG
        /// 没有启用LiveCommunicationKit，但启用了CallUI
        CallKitManager.shared.reportCallEnded(reason: endedReason)
        #endif
        
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
        hasAcceptedViaSystemUI = false
        hasReportedConnected = false
        currentState = .idle
        currentCallType = nil
        currentChannel = nil
        currentRemoteUser = nil
        currentToken = nil
        currentCallUUID = nil
        currentCallID = nil  // 清除服务端 callID
        localUser = nil
        callStartTime = nil
        stateLock.lock()
        remoteUsers.removeAll()
        stateLock.unlock()
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
    
    func onReceiveCall(callID: String, fromUserId: String, channelName: String, token: String, callType: CallType) {
        let user = CallUser(userId: fromUserId, name: fromUserId)
        manager?.receiveIncomingCall(callID: callID, from: user, channelName: channelName, token: token, callType: callType) { _ in }
    }
    func onCallAccepted(callID: String, fromUserId: String) { manager?.onCallAccepted(callID: callID, fromUserId: fromUserId) }
    func onCallRejected(callID: String, fromUserId: String, reason: String?) { manager?.onCallRejected(callID: callID, fromUserId: fromUserId, reason: reason) }
    func onCallHangup(callID: String, fromUserId: String) { manager?.onCallHangup(callID: callID, fromUserId: fromUserId) }
    func onCallCanceled(callID: String, fromUserId: String) { manager?.onCallCanceled(callID: callID, fromUserId: fromUserId) }
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
        // 被叫加入频道后从 .incoming 变为 .connecting（停止来电铃声）
        // 主叫加入频道后仍保持 .calling（继续播放呼叫等待音，直到对方接听）
        if currentState == .incoming {
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
            
            if useLiveCommunicationKit {
                if #available(iOS 17.4, *) {
                    LiveCommunicationKitManager.shared.reportCallConnected()
                } 
            }
            #if DEBUG
            CallKitManager.shared.reportCallConnected()
            #endif
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
            stateLock.lock()
            remoteUsers[uid] = user
            stateLock.unlock()
            DispatchQueue.main.async { [weak self] in
                self?.uiDelegate.remoteUserDidJoin(user)
            }
        }
    }
    
    public func engine(_ engine: AgoraEngineManager, didOfflineOfUid uid: UInt) {
        log("引擎回调: 远端用户离开 uid=\(uid)")
        // 锁保护 remoteUsers 字典的读写
        stateLock.lock()
        let user = remoteUsers[uid]
        if user != nil {
            remoteUsers.removeValue(forKey: uid)
        }
        stateLock.unlock()
        
        if let user = user {
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
        // 锁保护 remoteUsers 字典的 read-modify-write
        stateLock.lock()
        var foundUser: CallUser?
        if var user = remoteUsers[uid] {
            user.isVideoMuted = muted
            remoteUsers[uid] = user
            foundUser = user
        }
        stateLock.unlock()
        
        if let user = foundUser {
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
        // 锁保护 remoteUsers 字典的 read-modify-write
        stateLock.lock()
        var foundUser: CallUser?
        if var user = remoteUsers[uid] {
            user.isAudioMuted = muted
            remoteUsers[uid] = user
            foundUser = user
        }
        stateLock.unlock()
        
        if let user = foundUser {
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
            // 被叫：加入频道后从 .incoming → .connecting（停止来电铃声）
            // 主叫：保持 .calling 状态（继续播放呼叫等待音，直到对方接听）
            if currentState == .incoming {
                currentState = .connecting
            }
        case .connected:
            // 引擎连接成功
            // 被叫：.incoming → .connecting
            // 主叫：保持 .calling，等待对方接听信令
            if currentState == .incoming {
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
    
    public func engine(_ engine: AgoraEngineManager, firstRemoteAudioFrameDecodedOfUid uid: UInt, elapsed: Int) {
            guard currentState == .connected else { return }
            if !hasReportedConnected {
                hasReportedConnected = true
                if useLiveCommunicationKit {
                    if #available(iOS 17.4, *) {
                        LiveCommunicationKitManager.shared.reportCallConnected()
                    }
                }
                #if DEBUG
                CallKitManager.shared.reportCallConnected()
                #endif
            }
        }
}

// MARK: - CallKitManagerDelegate

#if DEBUG
extension CallManager: CallKitManagerDelegate {
    
    public func callKitManagerDidReset() {
        log("CallKit 重置，强制结束通话")
        if currentState != .idle {
            disconnectCall(error: nil, endedReason: .remoteEnded)
        }
    }
    
    /// 用户在系统来电界面点击了接听
    public func callKitManagerDidAcceptCall() {
        log("CallKit: 用户在系统来电界面点击了接听")
        // 标记用户已在系统界面接听
        hasAcceptedViaSystemUI = true
        acceptCall()
    }
    
    /// 用户在系统来电界面点击了拒绝
    public func callKitManagerDidRejectCall() {
        log("CallKit: 用户拒绝")
        rejectCall()
    }
    
    /// 系统来电界面消失（超时等）
    public func callKitManagerDidEndCall() {
        log("CallKit: 来电结束")
        // 如果还在 incoming 状态，说明用户没有在系统界面操作（可能是超时），挂断通话
        if currentState == .incoming {
            rejectCall()
        } else {
            hangUp()
        }
    }
    
    /// App 进入前台，CallKit 来电界面已关闭，但用户已在系统界面接听
    public func callKitManagerDidDismissWhileAccepted() {
        log("CallKit: 来电界面已关闭，用户已接听，保持通话")
        // 不需要做任何事，hasAcceptedViaSystemUI 已经在点击接听时设置为 true
        // handleAppDidBecomeActive 会处理 present 控制器
    }
}
#endif

// MARK: - LiveCommunicationKitManagerDelegate (iOS 17.4+)

@available(iOS 17.4, *)
extension CallManager: LiveCommunicationKitManagerDelegate {
    
    /// 用户点击了接听
    public func liveCommunicationKitDidAcceptCall(uuid: UUID, completion: @escaping (Bool) -> Void) {
        log("LiveCommunicationKit: 用户在来电界面点击了接听, currentState=\(currentState)")
        // 标记用户已在系统界面接听
        hasAcceptedViaSystemUI = true
        log("LiveCommunicationKit: 设置 hasAcceptedViaSystemUI=true, 开始调用 acceptCall")
        acceptCall(completion: completion)
    }
    
    /// 用户点击了拒绝/挂断
    public func liveCommunicationKitDidRejectCall(uuid: UUID) {
        log("LiveCommunicationKit: 用户拒绝/挂断, 当前状态=\(currentState)")
        
        // 根据当前状态决定执行拒绝还是挂断
        switch currentState {
        case .incoming:
            // 未接听的来电 → 拒绝
            rejectCall()
        case .calling, .connecting, .connected, .reconnecting:
            // 已接通的通话 → 挂断
            hangUp()
        default:
            log("⚠️ 拒绝/挂断忽略: 无效状态=\(currentState)")
            break
        }
    }
    
    /// 通话超时未接听
    public func liveCommunicationKitDidTimeout(uuid: UUID) {
        log("LiveCommunicationKit: 来电超时")
        if currentState == .incoming {
            hangUp()
        }
    }
    
    /// LiveCommunicationKit 重置
    public func liveCommunicationKitDidReset() {
        log("LiveCommunicationKit 重置，强制结束通话")
        if currentState != .idle {
            disconnectCall(error: nil, endedReason: .remoteEnded)
        }
    }
}
