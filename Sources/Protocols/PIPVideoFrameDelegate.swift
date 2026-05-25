//
//  PIPVideoFrameDelegate.swift
//  AgoraCallCore
//
//  Created by CallCore on 2021/12/2.
//

import Foundation
import CoreMedia
import CoreVideo
import AgoraRtcKit

/// PiP 视频帧代理，实现 AgoraVideoFrameDelegate，获取远端视频帧并送入 PictureInPictureManager
public class PIPVideoFrameDelegate: NSObject, AgoraVideoFrameDelegate {
    
    weak var pipManager: PictureInPictureManager?
    
    private var frameCount: Int64 = 0
    private var lastEnqueueTime: CFTimeInterval = 0

    /// PiP 视频帧节流间隔，默认 1/15 秒（15fps）。
    /// 可在外部按需调整以平衡画质与性能。
    public var frameThrottleInterval: TimeInterval = 1.0 / 15.0

    init(pipManager: PictureInPictureManager?) {
        self.pipManager = pipManager
        super.init()
    }
    
    // MARK: - AgoraVideoFrameDelegate
    
    /// 只读模式：不修改帧数据，不干扰 Agora 渲染管线
    public func getVideoFrameProcessMode() -> AgoraVideoFrameProcessMode {
        return .readOnly
    }
    
    /// 观察远端视频帧（渲染前）
    public func getObservedFramePosition() -> AgoraVideoFramePosition {
        return [.preRenderer]
    }
    
    /// 偏好 CVPixelBuffer 格式（最高效，无需格式转换）
    public func getVideoFormatPreference() -> AgoraVideoFormat {
        return .cvPixelBGRA
    }
    
    /// 远端视频帧回调 —— 在 preRenderer 位置触发
    public func onRenderVideoFrame(_ videoFrame: AgoraOutputVideoFrame, uid: UInt, channelId: String) -> Bool {
        let now = CACurrentMediaTime()
        guard now - lastEnqueueTime >= frameThrottleInterval else { return true }
        lastEnqueueTime = now
        
        guard let pixelBuffer = videoFrame.pixelBuffer else { return true }
        
        let timestamp = CMTime(value: frameCount, timescale: 30)
        frameCount += 1
        
        pipManager?.enqueueVideoFrame(pixelBuffer, timestamp: timestamp)
        return true
    }
    
    // 以下回调不需要实现，但协议要求声明
    public func onCapture(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool { return true }
    public func onPreEncode(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool { return true }
}
