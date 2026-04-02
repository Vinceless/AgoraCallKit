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

public class AgoraEngineManager: NSObject {
    public static let shared = AgoraEngineManager()
    public weak var delegate: AgoraEngineDelegate?
    
    private var engine: AgoraRtcEngineKit?
    private var appId: String = ""
    private var currentChannel: String?
    private var isVideoEnabled: Bool = false
    
    // 画中画代理
    private var videoFrameDelegate: PIPVideoFrameDelegate?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 配置
    public func configure(appId: String) {
        self.appId = appId
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.areaCode = .global
        engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        engine?.setChannelProfile(.communication)
        // 基础配置：开启音频，视频默认关闭
        engine?.enableAudio()
        engine?.enableVideo()
        engine?.disableVideo() // 初始关闭视频，在需要视频时再开启
        setupAudioSession()
        // 设置视频帧代理（用于画中画）
            videoFrameDelegate = PIPVideoFrameDelegate(pipManager: PictureInPictureManager.shared)
            engine?.setVideoFrameDelegate(videoFrameDelegate)
    }
    
    // 在清理时移除代理
    public func destroy() {
        engine?.setVideoFrameDelegate(nil)
        // ...
    }
    
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
    
    public func leaveChannel() {
        engine?.leaveChannel()
        currentChannel = nil
    }
    
    // MARK: - 本地视频渲染
    public func setupLocalVideoView(_ view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.uid = 0
        engine?.setupLocalVideo(canvas)
    }
    
    public func setupRemoteVideoView(_ view: UIView, forUid uid: UInt) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = view
        canvas.renderMode = .hidden
        canvas.uid = uid
        engine?.setupRemoteVideo(canvas)
    }
    
    public func removeRemoteVideoView(forUid uid: UInt) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.view = nil
        canvas.uid = uid
        engine?.setupRemoteVideo(canvas)
    }
    
    // MARK: - 音视频控制
    public func muteLocalAudio(_ mute: Bool) {
        engine?.muteLocalAudioStream(mute)
    }
    
    public func muteLocalVideo(_ mute: Bool) {
        engine?.muteLocalVideoStream(mute)
        delegate?.engine(self, localVideoMuted: mute)
    }
    
    public func setSpeakerEnabled(_ enabled: Bool) {
        engine?.setEnableSpeakerphone(enabled)
    }
    
    public func switchCamera() {
        engine?.switchCamera()
    }
    
    // MARK: - 工具
    public func getCurrentChannel() -> String? {
        return currentChannel
    }
    
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
