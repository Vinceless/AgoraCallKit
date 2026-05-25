//
//  CallUIDelegateMulticast.swift
//  AgoraCallKit
//
//  多播委托：支持多个 CallUIDelegate 同时监听回调
//

import Foundation

/// 多播委托管理器，使用 NSHashTable 弱引用，支持多个 delegate 同时接收回调
/// VC 销毁后自动清理，无需手动移除
/// 线程安全：NSLock 保护 delegates 的读写，RTC 引擎回调（后台线程）和 UI 注册（主线程）可安全并发
public final class CallUIDelegateMulticast: CallUIDelegate {
    
    private let lock = NSLock()
    private let delegates = NSHashTable<AnyObject>.weakObjects()
    
    /// 添加 delegate（弱引用，重复添加不会重复回调）
    public func add(_ delegate: CallUIDelegate) {
        lock.lock()
        defer { lock.unlock() }
        guard !delegates.allObjects.contains(where: { $0 === delegate as AnyObject }) else { return }
        delegates.add(delegate)
    }
    
    /// 移除 delegate
    public func remove(_ delegate: CallUIDelegate) {
        lock.lock()
        delegates.remove(delegate)
        lock.unlock()
    }
    
    /// 是否已包含某个 delegate
    public func contains(_ delegate: CallUIDelegate) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return delegates.allObjects.contains { $0 === delegate as AnyObject }
    }
    
    /// 当前所有存活的 delegate（线程安全快照）
    public var allDelegates: [CallUIDelegate] {
        lock.lock()
        defer { lock.unlock() }
        return delegates.allObjects.compactMap { $0 as? CallUIDelegate }
    }
    
    // MARK: - CallUIDelegate 转发
    
    public func callStateDidChange(_ state: CallState) {
        allDelegates.forEach { $0.callStateDidChange(state) }
    }
    
    public func didJoinChannel(withUser user: CallUser) {
        allDelegates.forEach { $0.didJoinChannel(withUser: user) }
    }
    
    public func didDisconnect(error: Error?) {
        allDelegates.forEach { $0.didDisconnect(error: error) }
    }
    
    public func remoteUserDidJoin(_ user: CallUser) {
        allDelegates.forEach { $0.remoteUserDidJoin(user) }
    }
    
    public func remoteUserDidLeave(_ user: CallUser) {
        allDelegates.forEach { $0.remoteUserDidLeave(user) }
    }
    
    public func didUpdateDuration(_ duration: TimeInterval) {
        allDelegates.forEach { $0.didUpdateDuration(duration) }
    }
    
    public func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {
        allDelegates.forEach { $0.didReceiveIncomingCall(from: user, callType: callType, channelName: channelName, token: token) }
    }
    
    public func didOccurError(_ error: Error) {
        allDelegates.forEach { $0.didOccurError(error) }
    }
    
    public func didCallTimeout() {
        allDelegates.forEach { $0.didCallTimeout() }
    }
    
    public func didReceiveDuplicateIncomingCall(from user: CallUser, callType: CallType, channelName: String) {
        allDelegates.forEach { $0.didReceiveDuplicateIncomingCall(from: user, callType: callType, channelName: channelName) }
    }
    
    public func remoteUserDidToggleVideo(_ user: CallUser, muted: Bool) {
        allDelegates.forEach { $0.remoteUserDidToggleVideo(user, muted: muted) }
    }
    
    public func remoteUserDidToggleAudio(_ user: CallUser, muted: Bool) {
        allDelegates.forEach { $0.remoteUserDidToggleAudio(user, muted: muted) }
    }
    
    public func localAudioMutedDidChange(_ muted: Bool) {
        allDelegates.forEach { $0.localAudioMutedDidChange(muted) }
    }
    
    public func localVideoMutedDidChange(_ muted: Bool) {
        allDelegates.forEach { $0.localVideoMutedDidChange(muted) }
    }
    
    public func didShowIncomingCallUIAfterForeground(from user: CallUser, callType: CallType, channelName: String, token: String) {
        allDelegates.forEach { $0.didShowIncomingCallUIAfterForeground(from: user, callType: callType, channelName: channelName, token: token) }
    }
    
    public func didAcceptIncomingCall(from user: CallUser, callType: CallType) {
        allDelegates.forEach { $0.didAcceptIncomingCall(from: user, callType: callType) }
    }
}
