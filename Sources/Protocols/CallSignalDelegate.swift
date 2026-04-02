//
//  CallSignalDelegate.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// 信令发送协议（由 App 层实现）
public protocol CallSignalDelegate: AnyObject {
    /// 发起通话请求
    /// - Parameters:
    ///   - toUserId: 被叫用户ID
    ///   - channelName: 频道名
    ///   - token: 声网 Token
    ///   - callType: 通话类型
    ///   - completion: 完成回调
    func sendCallRequest(toUserId: String, channelName: String, token: String, callType: CallType, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送接受通话响应
    func sendAcceptResponse(toUserId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送拒绝通话响应
    func sendRejectResponse(toUserId: String, reason: String?, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送挂断信令
    func sendHangupSignal(toUserId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送取消通话信令（主叫在对方未接听前取消）
    func sendCancelSignal(toUserId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 设置信令监听器（用于接收远端信令）
    func setListener(_ listener: CallSignalListener?)
}

/// 信令接收监听器（由 AgoraCallCore 实现，App 层收到信令后调用）
public protocol CallSignalListener: AnyObject {
    /// 收到来电
    func onReceiveCall(fromUserId: String, channelName: String, token: String, callType: CallType)
    /// 对方已接受
    func onCallAccepted(fromUserId: String)
    /// 对方拒绝
    func onCallRejected(fromUserId: String, reason: String?)
    /// 对方挂断
    func onCallHangup(fromUserId: String)
    /// 对方取消通话
    func onCallCanceled(fromUserId: String)
}
