//
//  AgoraEngineProtocol.swift
//  AgoraCallKit
//
//  引擎协议：解耦 CallManager 与 AgoraEngineManager，支持 Mock 测试
//

import UIKit
import AgoraRtcKit

/// 声网引擎管理协议，定义 CallManager 需要的引擎能力
public protocol AgoraEngineProtocol: AnyObject {
    /// 配置引擎
    func configure(appId: String)
    /// 加入频道
    @discardableResult
    func joinChannel(_ channel: String, token: String?, uid: UInt, isVideoCall: Bool) -> Bool
    /// 离开频道
    func leaveChannel()
    /// 开始/停止本地视频预览
    func startPreview()
    func stopPreview()
    /// 静音本地音频/视频
    func muteLocalAudio(_ mute: Bool)
    func muteLocalVideo(_ mute: Bool)
    /// 扬声器开关
    func setSpeakerEnabled(_ enabled: Bool)
    /// 切换摄像头
    func switchCamera()
    /// 视频渲染视图设置
    func setupLocalVideoView(_ view: UIView)
    func setupRemoteVideoView(_ view: UIView, forUid uid: UInt)
    func removeRemoteVideoView(forUid uid: UInt)
    /// PiP 捕获器
    func startPiPCapturer(remoteVideoView: UIView?)
    func stopPiPCapturer()
    /// 查询
    func getCurrentChannel() -> String?
    func isInChannel() -> Bool
}
