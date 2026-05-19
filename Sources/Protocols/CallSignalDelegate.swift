//
//  CallSignalDelegate.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

/// 信令发送协议，由 App 层实现，负责向服务器发送通话控制信令
public protocol CallSignalDelegate: AnyObject {
    /// 发起通话请求
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符（用于后续信令关联）
    ///   - toUserId: 被叫用户ID
    ///   - channelName: 频道名
    ///   - token: 声网 Token
    ///   - callType: 通话类型
    ///   - completion: 完成回调
    func sendCallRequest(callID: String, toUserId: String, channelName: String, token: String, callType: CallType, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送接受通话响应
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - toUserId: 被叫用户ID
    ///   - completion: 完成回调
    func sendAcceptResponse(callID: String, toUserId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送拒绝通话响应
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - toUserId: 被叫用户ID
    ///   - reason: 拒绝原因（可选）
    ///   - completion: 完成回调
    func sendRejectResponse(callID: String, toUserId: String, reason: String?, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送挂断信令
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - toUserId: 被叫用户ID
    ///   - completion: 完成回调
    func sendHangupSignal(callID: String, toUserId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 发送取消通话信令（主叫在对方未接听前取消）
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - toUserId: 被叫用户ID
    ///   - completion: 完成回调
    func sendCancelSignal(callID: String, toUserId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 设置信令监听器，用于接收远端信令
    func setListener(_ listener: CallSignalListener?)
}

/// 信令接收监听器，由 AgoraCallCore 实现，App 层收到信令后调用对应方法
public protocol CallSignalListener: AnyObject {
    /// 收到来电
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 主叫用户ID
    ///   - channelName: 频道名
    ///   - token: 声网 Token
    ///   - callType: 通话类型
    func onReceiveCall(callID: String, fromUserId: String, channelName: String, token: String, callType: CallType)
    
    /// 对方已接受
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 接受方用户ID
    func onCallAccepted(callID: String, fromUserId: String)
    
    /// 对方拒绝
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 拒绝方用户ID
    ///   - reason: 拒绝原因（可选）
    func onCallRejected(callID: String, fromUserId: String, reason: String?)
    
    /// 对方挂断
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 挂断方用户ID
    func onCallHangup(callID: String, fromUserId: String)
    
    /// 对方取消通话
    /// - Parameters:
    ///   - callID: 服务端返回的通话标识符
    ///   - fromUserId: 取消方用户ID
    func onCallCanceled(callID: String, fromUserId: String)
}
