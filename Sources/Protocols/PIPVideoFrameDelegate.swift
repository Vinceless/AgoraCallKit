//
//  PIPVideoFrameDelegate.swift
//  AgoraCallKit
//
//  Created by CallCore on 2021/12/2.
//

import AgoraRtcKit
import CoreMedia

open class PIPVideoFrameDelegate: NSObject, AgoraVideoFrameDelegate {
    
    weak var pipManager: PictureInPictureManager?
    private var lastTimestamp: CMTime = .zero
    
    init(pipManager: PictureInPictureManager?) {
        self.pipManager = pipManager
        super.init()
    }
    
    // 本地捕获的视频帧（前置/后置摄像头）
    public func onCapture(_ frame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        // 将视频帧传递给画中画管理器
        if let pixelBuffer = frame.pixelBuffer {
            let timestamp = CMTime(value: CMTimeValue(frame.renderTimeMs), timescale: 1000)
            pipManager?.enqueueVideoFrame(pixelBuffer, timestamp: timestamp)
        }
        // 返回 false：让 Agora SDK 内部也继续处理该帧，保持默认渲染管线正常工作
        // 这样即使在 PiP 模式下，Agora 的本地和远程渲染也不会中断
        return false
    }
    
    // 远端渲染的视频帧
    public func onRenderVideoFrame(_ frame: AgoraOutputVideoFrame, uid: UInt, channelId: String) -> Bool {
        // 如果需要显示远端视频，这里同样可以传递
        // 可以按需选择：比如显示本地或远端
        return true
    }
    
    // 可选：设置视频格式偏好
    public func getVideoFormatPreference() -> AgoraVideoFormat {
        return .default  // 使用默认格式
    }
}
