//
//  PictureInPictureManager.swift
//  AgoraCallCore
//
//  Created by Vnce on 2021/12/2.
//

import UIKit
import AVKit
import CoreMedia
import CoreVideo
import AgoraRtcKit

public class PictureInPictureManager: NSObject {
    static let shared = PictureInPictureManager()
    
    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var playerLayer: AVPlayerLayer?  // 用于包装 displayLayer
    private var videoSize: CGSize = .zero
    
    private override init() {}
    
    /// 初始化画中画视图（应在通话开始后调用，传入视频渲染视图的尺寸）
    func setup(initialSize: CGSize) {
        videoSize = initialSize
        // 创建 AVSampleBufferDisplayLayer 用于渲染视频帧
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspectFill
        layer.frame = CGRect(origin: .zero, size: initialSize)
        sampleBufferDisplayLayer = layer
        
        // 创建 AVPlayerLayer 包装 displayLayer（AVPictureInPictureController 需要）
        let playerLayer = AVPlayerLayer(player: nil)  // 不需要播放器，仅用其 layer 作为容器
        playerLayer.addSublayer(layer)
        self.playerLayer = playerLayer
        
        // 创建画中画控制器
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
        }
    }
    
    /// 启动画中画
    func start() {
        guard let controller = pipController else { return }
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
        }
    }
    
    /// 停止画中画
    func stop() {
        pipController?.stopPictureInPicture()
    }
    
    /// 接收视频帧（由 Agora 回调调用）
    func enqueueVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let displayLayer = sampleBufferDisplayLayer else { return }
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr, let formatDesc = formatDescription else { return }
        
        let result = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if result == noErr, let buffer = sampleBuffer {
            if displayLayer.status == .failed {
                displayLayer.flush()
            }
            displayLayer.enqueue(buffer)
        }
    }
}

extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // 可选：隐藏原有视频视图
        NotificationCenter.default.post(name: .pipWillStart, object: nil)
    }
    
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // 画中画已开始
    }
    
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // 可选：恢复原有视频视图
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        NotificationCenter.default.post(name: .pipDidStop, object: nil)
    }
}

extension Notification.Name {
    static let pipWillStart = Notification.Name("pipWillStart")
    static let pipDidStop = Notification.Name("pipDidStop")
}
