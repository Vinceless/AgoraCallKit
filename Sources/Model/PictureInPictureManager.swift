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
    private var videoSize: CGSize = .zero
    
    // 关键：displayLayer 必须被添加到一个在 window 中的 view 上，PiP 才能工作
    private var pipRenderView: UIView?
    
    // 是否正在播放（用于 AVPictureInPictureSampleBufferPlaybackDelegate）
    private var isPlaying: Bool = true
    
    // 上一帧的时间戳（确保递增）
    private var lastEnqueuedTimestamp: CMTime = .zero
    
    // 是否已经初始化
    private var isSetup: Bool = false
    
    private override init() {}
    
    /// 初始化画中画视图（应在通话连接后、视图布局完成后调用）
    func setup(initialSize: CGSize) {
        videoSize = initialSize
        
        // 先清理旧的
        cleanup()
        
        // 尺寸不能为零
        let safeSize = initialSize.width > 0 && initialSize.height > 0 ? initialSize : CGSize(width: 360, height: 640)
        
        // 创建 AVSampleBufferDisplayLayer 用于渲染视频帧
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = CGRect(origin: .zero, size: safeSize)
        self.sampleBufferDisplayLayer = displayLayer
        
        // 创建一个 view 来持有 displayLayer，并将其添加到当前 key window 上
        // AVPictureInPictureController 要求 layer 必须在一个 window 的 view 层级中
        let renderView = UIView(frame: CGRect(origin: .zero, size: safeSize))
        renderView.layer.addSublayer(displayLayer)
        // 注意：alpha 不能为 0！PiP 系统要求内容可见，alpha 为 0 会被系统忽略
        // 使用 0.01 是不够的，必须在可见范围内
        renderView.alpha = 1.0
        renderView.isUserInteractionEnabled = false
        renderView.backgroundColor = .clear
        // 将 renderView 放到屏幕外（仍然在 window 层级中，但用户看不到）
        renderView.frame = CGRect(x: -safeSize.width, y: -safeSize.height, width: safeSize.width, height: safeSize.height)
        pipRenderView = renderView
        
        // 将 renderView 添加到 key window
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(renderView)
            print("[PiP] renderView added to key window, frame=\(renderView.frame)")
        } else if let window = UIApplication.shared.windows.first {
            window.addSubview(renderView)
            print("[PiP] renderView added to first window, frame=\(renderView.frame)")
        } else {
            print("[PiP] Warning: No window found for PiP renderView")
        }
        
        // 创建画中画控制器
        if AVPictureInPictureController.isPictureInPictureSupported() {
            if #available(iOS 15.0, *) {
                // iOS 15+: 使用 ContentSource + AVSampleBufferDisplayLayer
                let contentSource = AVPictureInPictureController.ContentSource(
                    sampleBufferDisplayLayer: displayLayer,
                    playbackDelegate: self
                )
                pipController = AVPictureInPictureController(contentSource: contentSource)
                pipController?.delegate = self
                // 关键：设置自动启动，这样 App 进入后台时系统会自动启动 PiP
                // 不能在后台手动调用 startPictureInPicture()，必须在后台之前由系统自动触发
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
                print("[PiP] Controller created with ContentSource (iOS 15+), autoStart=true")
            } else {
                // iOS 14: 不支持 AVSampleBufferDisplayLayer 的 PiP
                print("[PiP] Warning: iOS 14 does not support AVSampleBufferDisplayLayer PiP")
                return
            }
            isSetup = true
        } else {
            print("[PiP] Error: Picture in Picture not supported on this device")
        }
    }
    
    /// 手动启动画中画（必须在 App 前台时调用）
    func start() {
        guard let controller = pipController else {
            print("[PiP] Error: pipController is nil, setup not called or failed")
            return
        }
        
        guard isSetup else {
            print("[PiP] Error: setup not completed")
            return
        }
        
        isPlaying = true
        print("[PiP] Attempting to start, isPictureInPicturePossible = \(controller.isPictureInPicturePossible)")
        
        // 确保 renderView 在 window 层级中
        if pipRenderView?.window == nil {
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                if let renderView = pipRenderView {
                    window.addSubview(renderView)
                    print("[PiP] renderView re-added to key window")
                }
            }
        }
        
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
            print("[PiP] startPictureInPicture called")
        } else {
            print("[PiP] isPictureInPicturePossible = false, cannot start now")
            print("[PiP] PiP will auto-start when app goes to background if canStartPictureInPictureAutomaticallyFromInline = true")
        }
    }
    
    /// 停止画中画
    func stop() {
        pipController?.stopPictureInPicture()
    }
    
    /// 清理资源
    func cleanup() {
        pipController = nil
        sampleBufferDisplayLayer = nil
        pipRenderView?.removeFromSuperview()
        pipRenderView = nil
        isSetup = false
        lastEnqueuedTimestamp = .zero
    }
    
    /// 接收视频帧（由 Agora 回调调用）
    func enqueueVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let displayLayer = sampleBufferDisplayLayer else { return }
        
        // 确保时间戳递增（AVSampleBufferDisplayLayer 要求）
        let safeTimestamp: CMTime
        if timestamp <= lastEnqueuedTimestamp {
            safeTimestamp = CMTimeAdd(lastEnqueuedTimestamp, CMTime(value: 1, timescale: 30))
        } else {
            safeTimestamp = timestamp
        }
        lastEnqueuedTimestamp = safeTimestamp
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: safeTimestamp,
            decodeTimeStamp: .invalid
        )
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr, let formatDesc = formatDescription else {
            print("[PiP] Error: CMVideoFormatDescriptionCreateForImageBuffer failed with status \(status)")
            return
        }
        
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
        } else {
            print("[PiP] Error: CMSampleBufferCreateForImageBuffer failed with result \(result)")
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("[PiP] Will start")
        NotificationCenter.default.post(name: .pipWillStart, object: nil)
    }
    
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("[PiP] Did start successfully")
    }
    
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("[PiP] Will stop")
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("[PiP] Did stop")
        NotificationCenter.default.post(name: .pipDidStop, object: nil)
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("[PiP] Failed to start with error: \(error.localizedDescription)")
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        print("[PiP] Restore user interface requested")
        completionHandler(true)
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate (iOS 15+)
@available(iOS 15.0, *)
extension PictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        isPlaying = playing
        print("[PiP] setPlaying: \(playing)")
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // 实时通话，使用无限时间范围
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return !isPlaying
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        print("[PiP] Render size changed: \(newRenderSize.width)x\(newRenderSize.height)")
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension Notification.Name {
    static let pipWillStart = Notification.Name("pipWillStart")
    static let pipDidStop = Notification.Name("pipDidStop")
    static let needRestoreFloatingWindow = Notification.Name("needRestoreFloatingWindow")
}
