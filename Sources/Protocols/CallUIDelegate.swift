//
//  CallUIDelegate.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// UI 回调协议，由 AgoraCallCore 调用，App 层的 UI 实现该协议以接收状态更新
public protocol CallUIDelegate: AnyObject {
    /// 通话状态变化
    func callStateDidChange(_ state: CallState)
    /// 已加入频道，获得本地用户信息
    func didJoinChannel(withUser user: CallUser)
    /// 通话断开（正常挂断或错误）
    func didDisconnect(error: Error?)
    /// 远端用户加入（单聊为对方，群聊为任意成员）
    func remoteUserDidJoin(_ user: CallUser)
    /// 远端用户离开
    func remoteUserDidLeave(_ user: CallUser)
    /// 通话时长更新（每秒）
    func didUpdateDuration(_ duration: TimeInterval)
    /// 收到来电，App 层应展示来电界面
    func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String)
    /// 发生错误
    func didOccurError(_ error: Error)
    /// 呼叫超时（对方未接听），App 端应调用 hangUp() 挂断
    func didCallTimeout()
    /// 收到同一通话的重复来电推送（channel 相同），App 端可弹 Toast 提示
    func didReceiveDuplicateIncomingCall(from user: CallUser, callType: CallType, channelName: String)
    /// 远端用户视频静音状态变化
    func remoteUserDidToggleVideo(_ user: CallUser, muted: Bool)
    /// 远端用户音频静音状态变化
    func remoteUserDidToggleAudio(_ user: CallUser, muted: Bool)
    /// 本地用户音频静音状态变化
    func localAudioMutedDidChange(_ muted: Bool)
    /// 本地用户视频静音状态变化
    func localVideoMutedDidChange(_ muted: Bool)
}

/// 提供默认空实现，方便子类只重写部分方法
public extension CallUIDelegate {
    func callStateDidChange(_ state: CallState) {}
    func didJoinChannel(withUser user: CallUser) {}
    func didDisconnect(error: Error?) {}
    func remoteUserDidJoin(_ user: CallUser) {}
    func remoteUserDidLeave(_ user: CallUser) {}
    func didUpdateDuration(_ duration: TimeInterval) {}
    func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {}
    func didOccurError(_ error: Error) {}
    func didCallTimeout() {}
    func didReceiveDuplicateIncomingCall(from user: CallUser, callType: CallType, channelName: String) {}
    func remoteUserDidToggleVideo(_ user: CallUser, muted: Bool) {}
    func remoteUserDidToggleAudio(_ user: CallUser, muted: Bool) {}
    func localAudioMutedDidChange(_ muted: Bool) {}
    func localVideoMutedDidChange(_ muted: Bool) {}
}
