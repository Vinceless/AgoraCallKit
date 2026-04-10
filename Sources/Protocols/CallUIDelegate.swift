//
//  CallUIDelegate.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// UI 回调协议（由 AgoraCallCore 调用，App 层的 UI 实现该协议以接收状态更新）
public protocol CallUIDelegate: AnyObject {
    /// 通话状态变化
    func callStateDidChange(_ state: CallState)
    /// 已加入频道，获得本地 用户
    func didConnect(withUser user: CallUser)
    /// 通话断开（可能是正常挂断或错误）
    func didDisconnect(error: Error?)
    /// 远端用户加入（单人通话时只有对方一人；群组会有多人）
    func remoteUserDidJoin(_ user: CallUser)
    /// 远端用户离开
    func remoteUserDidLeave(_ user: CallUser)
    /// 通话时长更新（每秒）
    func didUpdateDuration(_ duration: TimeInterval)
    /// 收到来电（App 层应展示来电界面）
    func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String)
    /// 发生错误（可展示提示）
    func didOccurError(_ error: Error)
}

// 提供默认空实现，方便子类只重写部分方法
public extension CallUIDelegate {
    func callStateDidChange(_ state: CallState) {}
    func didConnect(withUser user: CallUser) {}
    func didDisconnect(error: Error?) {}
    func remoteUserDidJoin(_ user: CallUser) {}
    func remoteUserDidLeave(_ user: CallUser) {}
    func didUpdateDuration(_ duration: TimeInterval) {}
    func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {}
    func didOccurError(_ error: Error) {}
}
