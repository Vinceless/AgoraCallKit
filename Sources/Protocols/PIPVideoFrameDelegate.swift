//
//  PIPVideoFrameDelegate.swift
//  AgoraCallKit
//
//  Created by CallCore on 2021/12/2.
//

import Foundation
import CoreMedia
import CoreVideo
import AgoraRtcKit

/// PiP 视频帧代理
/// 使用 AgoraVideoFrameDelegate 的 onRenderVideoFrame 获取远端视频帧
/// processMode = .readOnly，不修改帧数据，不干扰 Agora 内部渲染管线
/// 观察位置 = .preRenderer，在远端视频帧渲染前获取
public class PIPVideoFrameDelegate: NSObject, AgoraVideoFrameDelegate {
    
    weak var pipManager: PictureInPictureManager?
    
    // 帧计数（用于生成递增时间戳）
    private var frameCount: Int64 = 0
    
    // 上一次送帧时间（节流，避免送帧频率过高）
    private var lastEnqueueTime: CFTimeInterval = 0
    private let enqueueInterval: CFTimeInterval = 1.0 / 15.0  // 15fps
    
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
        guard now - lastEnqueueTime >= enqueueInterval else { return true }
        lastEnqueueTime = now
        
        guard let pixelBuffer = videoFrame.pixelBuffer else { return true }
        
        let timestamp = CMTime(value: frameCount, timescale: 30)
        frameCount += 1
        
        pipManager?.enqueueVideoFrame(pixelBuffer, timestamp: timestamp)
        return true
    }
    
    // 以下回调不需要实现，但协议要求声明
    
    public func onCapture(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        return true
    }
    
    public func onPreEncode(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        return true
    }
}
