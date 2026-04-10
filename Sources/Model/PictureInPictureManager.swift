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
    private var playerLayer: AVPlayerLayer?
    private var videoSize: CGSize = .zero
    
    // 背景渲染目标视图（用于画中画时持有 layer）
    private var backgroundRenderView: UIView?
    
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
        let playerLayer = AVPlayerLayer(player: nil)
        playerLayer.addSublayer(layer)
        playerLayer.frame = CGRect(origin: .zero, size: initialSize)
        self.playerLayer = playerLayer
        
        // 创建背景视图来持有 playerLayer
        let bgView = UIView(frame: CGRect(origin: .zero, size: initialSize))
        bgView.layer.addSublayer(playerLayer)
        backgroundRenderView = bgView
        
        // 创建画中画控制器
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
            // 启用 PiP 前需要先启用相关属性
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    /// 启动画中画
    func start() {
        guard let controller = pipController else {
            print("PiP Error: pipController is nil")
            return
        }
        
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
        } else {
            print("PiP Error: PiP not possible, isPictureInPicturePossible = false")
            // 可能需要等待一段时间后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
                }
            }
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
            duration: CMTime(value: 1, timescale: 30), // 假设30fps
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
            // 确保在主线程操作
            DispatchQueue.main.async {
                if displayLayer.status == .failed {
                    displayLayer.flush()
                }
                displayLayer.enqueue(buffer)
            }
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
    static let needRestoreFloatingWindow = Notification.Name("needRestoreFloatingWindow")
}
