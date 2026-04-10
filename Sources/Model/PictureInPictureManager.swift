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
    
    // PiP 渲染视图（放在屏幕外，Agora 远端视频的第二个渲染目标）
    private var pipRenderView: UIView?
    
    // 是否正在播放（用于 AVPictureInPictureSampleBufferPlaybackDelegate）
    private var isPlaying: Bool = true
    
    // 上一帧的时间戳（确保递增）
    private var lastEnqueuedTimestamp: CMTime = .zero
    
    // 是否已经初始化
    private var isSetup: Bool = false
    
    // 是否正在通话中（用于控制 PiP 自动启动）
    private var isInCall: Bool = false
    
    private override init() {}
    
    /// 初始化画中画视图
    /// - Parameter initialSize: 视频尺寸
    func setup(initialSize: CGSize) {
        videoSize = initialSize
        isInCall = true
        
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
        // 重要：view 必须在 window 层级中且 frame 在 window bounds 内，
        // 否则 AVPictureInPictureController 无法识别为 inline 内容
        let renderView = UIView(frame: CGRect(origin: .zero, size: safeSize))
        renderView.layer.addSublayer(displayLayer)
        renderView.isUserInteractionEnabled = false
        renderView.backgroundColor = .clear
        renderView.alpha = 0.01  // 几乎不可见但系统认为可见，PiP 需要这个
        pipRenderView = renderView
        
        // 将 renderView 添加到 key window
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(renderView)
        } else if let window = UIApplication.shared.windows.first {
            window.addSubview(renderView)
        }
        
        // 创建画中画控制器
        if AVPictureInPictureController.isPictureInPictureSupported() {
            if #available(iOS 15.0, *) {
                let contentSource = AVPictureInPictureController.ContentSource(
                    sampleBufferDisplayLayer: displayLayer,
                    playbackDelegate: self
                )
                pipController = AVPictureInPictureController(contentSource: contentSource)
                pipController?.delegate = self
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
                print("[PiP] Controller created, isPictureInPicturePossible: \(pipController?.isPictureInPicturePossible ?? false)")
            } else {
                return
            }
            isSetup = true
        } else {
            print("[PiP] Picture in Picture not supported on this device")
        }
    }
    
    /// 通话结束，清理画中画（防止通话结束后还进入 PiP）
    func endCall() {
        isInCall = false
        // 如果 PiP 正在运行，先停止
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        cleanup()
    }
    
    /// 手动启动画中画（必须在 App 前台时调用）
    func start() {
        guard isSetup, isInCall else {
            print("[PiP] Cannot start: isSetup=\(isSetup), isInCall=\(isInCall)")
            return
        }
        isPlaying = true
        if pipController?.isPictureInPicturePossible == true {
            pipController?.startPictureInPicture()
            print("[PiP] startPictureInPicture called")
        } else {
            print("[PiP] Cannot start: isPictureInPicturePossible=false, hasEnqueuedFrames=\(hasEnqueuedFrames)")
            // 如果还没有帧数据，延迟重试
            if hasEnqueuedFrames {
                // 有帧但 pip 不可用，可能是 layer 状态问题
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.isInCall else { return }
                    if self.pipController?.isPictureInPicturePossible == true {
                        self.pipController?.startPictureInPicture()
                        print("[PiP] Retry: startPictureInPicture called")
                    } else {
                        print("[PiP] Retry failed: isPictureInPicturePossible still false")
                    }
                }
            }
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
        hasEnqueuedFrames = false
        lastEnqueuedTimestamp = .zero
    }
    
    /// 是否已有帧入队（PiP 需要 layer 中有内容才能启动）
    private var hasEnqueuedFrames: Bool = false
    
    /// 接收视频帧（由 AgoraVideoFrameDelegate 回调送入）
    func enqueueVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let displayLayer = sampleBufferDisplayLayer else { return }
        
        // 确保时间戳递增
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
            if !hasEnqueuedFrames {
                hasEnqueuedFrames = true
                print("[PiP] First frame enqueued, pipPossible=\(pipController?.isPictureInPicturePossible ?? false)")
            }
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
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return !isPlaying
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
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
