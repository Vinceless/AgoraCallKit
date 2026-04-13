//
//  AgoraEngineManager.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation
import AgoraRtcKit
import AVFoundation

/// 声网引擎代理（供 AgoraCallCore 内部使用）
public protocol AgoraEngineDelegate: AnyObject {
    /// 已加入频道
    func engine(_ engine: AgoraEngineManager, didJoinChannel channel: String, uid: UInt)
    /// 已离开频道
    func engine(_ engine: AgoraEngineManager, didLeaveChannel channel: String)
    /// 远端用户加入
    func engine(_ engine: AgoraEngineManager, didJoinedOfUid uid: UInt)
    /// 远端用户离开
    func engine(_ engine: AgoraEngineManager, didOfflineOfUid uid: UInt)
    /// 错误发生
    func engine(_ engine: AgoraEngineManager, didOccurError error: Error)
    /// 本地视频静音状态变化
    func engine(_ engine: AgoraEngineManager, localVideoMuted muted: Bool)
    /// 远端视频静音状态变化
    func engine(_ engine: AgoraEngineManager, remoteVideoMuted muted: Bool, ofUid uid: UInt)
    /// 连接状态变化
    func engine(_ engine: AgoraEngineManager, connectionStateChanged state: AgoraConnectionState)
}

/// 声网引擎管理器，封装 AgoraRtcEngineKit 的常用操作
public class AgoraEngineManager: NSObject {
    public static let shared = AgoraEngineManager()
    public weak var delegate: AgoraEngineDelegate?
    
    private var engine: AgoraRtcEngineKit?
    private var appId: String = ""
    private var currentChannel: String?
    private var isVideoEnabled: Bool = false
    
    // PiP 视频帧代理
    private var pipVideoFrameDelegate: PIPVideoFrameDelegate?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 配置
    /// 配置声网引擎，应在 App 启动时调用
    /// - Parameter appId: 声网 App ID
    public func configure(appId: String) {
        self.appId = appId
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.areaCode = .global
        engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine?.setChannelProfile(.communication)
        engine?.enableAudio()
        engine?.enableVideo()
        engine?.disableVideo() // 初始关闭视频，需要时再开启
        setupAudioSession()
        
        // 设置视频编码配置
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: CGSize(width: 640, height: 480),
            frameRate: 15,
            bitrate: 400,
            orientationMode: .fixedPortrait,
            mirrorMode: .auto
        )
        engine?.setVideoEncoderConfiguration(videoConfig)
    }
    
    /// 销毁引擎，释放资源
    public func destroy() {
        stopPiPCapturer()
        engine?.leaveChannel()
        AgoraRtcEngineKit.destroy()
        engine = nil
    }
    
    /// 配置音频会话，支持蓝牙和扬声器
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    // MARK: - 频道管理
    /// 加入频道
    /// - Parameters:
    ///   - channel: 频道名
    ///   - token: 声网 Token（可选）
    ///   - uid: 用户ID
    ///   - isVideoCall: 是否为视频通话
    /// - Returns: 是否成功发起加入请求
    @discardableResult
    public func joinChannel(_ channel: String, token: String?, uid: UInt, isVideoCall: Bool) -> Bool {
        guard let engine = engine else { return false }
        
        if isVideoCall {
            engine.enableVideo()
            isVideoEnabled = true
        } else {
            engine.disableVideo()
            isVideoEnabled = false
        }
        
        let option = AgoraRtcChannelMediaOptions()
        option.clientRoleType = .broadcaster
        option.channelProfile = .communication
        
        let result = engine.joinChannel(byToken: token, channelId: channel, uid: uid, mediaOptions: option)
        if result == 0 {
            currentChannel = channel
            return true
        }
        return false
    }
    
    /// 开始本地视频预览
    public func startPreview() {
        engine?.startPreview()
    }
    
    /// 停止本地视频预览
    public func stopPreview() {
        engine?.stopPreview()
    }
    
    /// 离开当前频道
    public func leaveChannel() {
        stopPiPCapturer()
        engine?.leaveChannel()
        currentChannel = nil
    }
    
    // MARK: - PiP 视频帧代理
    /// 启动 PiP 视频帧代理，通过 AgoraVideoFrameDelegate 获取视频帧
    /// - Parameter remoteVideoView: 远端视频渲染视图（用于尺寸参考）
    public func startPiPCapturer(remoteVideoView: UIView?) {
        guard pipVideoFrameDelegate == nil else { return }
        let delegate = PIPVideoFrameDelegate(pipManager: PictureInPictureManager.shared)
        engine?.setVideoFrameDelegate(delegate)
        pipVideoFrameDelegate = delegate
    }
    
    /// 停止 PiP 视频帧代理
    public func stopPiPCapturer() {
        if pipVideoFrameDelegate != nil {
            engine?.setVideoFrameDelegate(nil)
            pipVideoFrameDelegate = nil
        }
    }
    
    // MARK: - 本地视频渲染
    /// 设置本地视频渲染视图
    /// - Parameter view: 用于渲染的 UIView
    public func setupLocalVideoView(_ view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.uid = 0
        engine?.setupLocalVideo(canvas)
    }
    
    /// 设置远端视频渲染视图
    /// - Parameters:
    ///   - view: 用于渲染的 UIView
    ///   - uid: 远端用户ID
    public func setupRemoteVideoView(_ view: UIView, forUid uid: UInt) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.uid = uid
        engine?.setupRemoteVideo(canvas)
    }
    
    /// 移除远端视频渲染视图
    /// - Parameter uid: 远端用户ID
    public func removeRemoteVideoView(forUid uid: UInt) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = nil
        canvas.uid = uid
        engine?.setupRemoteVideo(canvas)
    }
    
    // MARK: - 音视频控制
    /// 静音/取消静音本地音频
    public func muteLocalAudio(_ mute: Bool) {
        engine?.muteLocalAudioStream(mute)
    }
    
    /// 静音/取消静音本地视频
    public func muteLocalVideo(_ mute: Bool) {
        engine?.muteLocalVideoStream(mute)
        delegate?.engine(self, localVideoMuted: mute)
    }
    
    /// 开启/关闭扬声器
    public func setSpeakerEnabled(_ enabled: Bool) {
        engine?.setEnableSpeakerphone(enabled)
    }
    
    /// 切换前后摄像头
    public func switchCamera() {
        engine?.switchCamera()
    }
    
    // MARK: - 工具
    /// 获取当前频道名
    public func getCurrentChannel() -> String? {
        return currentChannel
    }
    
    /// 是否已在频道中
    public func isInChannel() -> Bool {
        return currentChannel != nil
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraEngineManager: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        delegate?.engine(self, didJoinChannel: channel, uid: uid)
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        delegate?.engine(self, didLeaveChannel: currentChannel ?? "")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        delegate?.engine(self, didJoinedOfUid: uid)
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        delegate?.engine(self, didOfflineOfUid: uid)
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        let error = NSError(domain: "AgoraEngine", code: Int(errorCode.rawValue), userInfo: [NSLocalizedDescriptionKey: "Agora error: \(errorCode.rawValue)"])
        delegate?.engine(self, didOccurError: error)
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid uid: UInt) {
        delegate?.engine(self, remoteVideoMuted: muted, ofUid: uid)
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        delegate?.engine(self, connectionStateChanged: state)
    }
}
