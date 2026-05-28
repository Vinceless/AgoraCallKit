//
//  CallSession.swift
//  AgoraCallKit
//
//  通话会话对象：封装单次通话的完整上下文，减少 CallManager 职责，支持多路通话扩展
//

import Foundation

/// 通话会话对象，管理一次通话从发起到结束的完整上下文
public final class CallSession: @unchecked Sendable {

    // MARK: - 线程安全
    private let lock = NSLock()

    // MARK: - 基础信息
    /// 通话代际标识（递增计数器），用于过滤残留的旧通话引擎回调
    public let callGeneration: UInt64
    /// 通话唯一标识符（服务端返回）
    public private(set) var callID: String
    /// 频道名
    public private(set) var channelName: String
    /// Agora Token
    public private(set) var token: String?
    /// 通话类型（音频/视频）
    public private(set) var callType: CallType
    /// 是否主叫方
    public let isCaller: Bool

    // MARK: - 用户信息
    /// 系统来电界面 UUID
    public var callUUID: UUID?
    /// 本地用户
    public var localUser: CallUser?

    /// 远端用户（单聊），锁保护读写
    private var _remoteUser: CallUser?
    public var remoteUser: CallUser? {
        get { lock.lock(); defer { lock.unlock() }; return _remoteUser }
        set { lock.lock(); _remoteUser = newValue; lock.unlock() }
    }

    /// 群组远端用户，锁保护读写
    private var _remoteUsers: [UInt: CallUser] = [:]
    public var remoteUsers: [UInt: CallUser] {
        get { lock.lock(); defer { lock.unlock() }; return _remoteUsers }
    }
    public func remoteUsersSnapshot() -> [CallUser] {
        lock.lock(); defer { lock.unlock() }
        return Array(_remoteUsers.values)
    }
    public func setRemoteUser(_ user: CallUser, forUid uid: UInt) {
        lock.lock(); _remoteUsers[uid] = user; lock.unlock()
    }
    public func removeRemoteUser(forUid uid: UInt) -> CallUser? {
        lock.lock(); defer { lock.unlock() }
        return _remoteUsers.removeValue(forKey: uid)
    }
    public func remoteUser(forUid uid: UInt) -> CallUser? {
        lock.lock(); defer { lock.unlock() }
        return _remoteUsers[uid]
    }
    public func removeAllRemoteUsers() {
        lock.lock(); _remoteUsers.removeAll(); lock.unlock()
    }

    // MARK: - 时间追踪
    /// 通话开始时间，锁保护读写
    private var _startTime: Date?
    public var startTime: Date? {
        get { lock.lock(); defer { lock.unlock() }; return _startTime }
        set { lock.lock(); _startTime = newValue; lock.unlock() }
    }

    /// 获取当前通话时长
    public func currentDuration() -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let start = _startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - 状态标志
    /// 用户是否通过系统来电界面（CallKit/LiveCommunicationKit）点击了接听，锁保护
    private var _hasAcceptedViaSystemUI = false
    public var hasAcceptedViaSystemUI: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _hasAcceptedViaSystemUI }
        set { lock.lock(); _hasAcceptedViaSystemUI = newValue; lock.unlock() }
    }

    /// 防止重复上报 connected，锁保护
    private var _hasReportedConnected = false
    public var hasReportedConnected: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _hasReportedConnected }
        set { lock.lock(); _hasReportedConnected = newValue; lock.unlock() }
    }

    /// 原子地标记已上报 connected，返回 true 表示首次标记成功（调用方负责上报）
    /// 防止 didJoinedOfUid 和 firstRemoteAudioFrameDecodedOfUid 并发的重复上报
    public func markReportedConnected() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !_hasReportedConnected else { return false }
        _hasReportedConnected = true
        return true
    }

    // MARK: - 初始化

    public init(callID: String = "", channelName: String, token: String? = nil, callType: CallType, isCaller: Bool, callGeneration: UInt64 = 0) {
        self.callGeneration = callGeneration
        self.callID = callID
        self.channelName = channelName
        self.token = token
        self.callType = callType
        self.isCaller = isCaller
    }

    /// 更新 callID（信令应答时可能回填）
    public func updateCallID(_ newCallID: String) {
        guard callID.isEmpty else {
            AgoraLogger.warning("callID 已存在 (\(callID))，忽略更新为 \(newCallID)", module: "CallSession")
            return
        }
        callID = newCallID
        AgoraLogger.debug("callID 更新为 \(newCallID)", module: "CallSession")
    }

    /// 更新 token
    public func updateToken(_ newToken: String) {
        token = newToken
    }
}
