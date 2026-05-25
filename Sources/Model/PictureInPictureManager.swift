//
//  PictureInPictureManager.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/12/2.
//

import UIKit
import AVKit
import CoreMedia
import CoreVideo
import AgoraRtcKit

/// 画中画管理器，负责接收视频帧并通过 AVSampleBufferDisplayLayer 渲染到画中画
public class PictureInPictureManager: NSObject {
    static let shared = PictureInPictureManager()

    // MARK: - 线程安全
    /// 保护可变属性的锁：视频帧回调（后台线程）与 UI 操作（主线程）会并发访问
    private let lock = NSLock()

    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var videoSize: CGSize = .zero
    
    /// 画中画渲染视图（放在屏幕外，Agora 远端视频的第二个渲染目标）
    private var pipRenderView: UIView?
    
    private var isPlaying: Bool = true
    private var lastEnqueuedTimestamp: CMTime = .zero
    private var isSetup: Bool = false
    private var isInCall: Bool = false
    private var hasEnqueuedFrames: Bool = false
    
    private override init() {}
    
    /// 初始化画中画视图
    /// - Parameter initialSize: 视频尺寸（通常从远端视频视图获取）
    func setup(initialSize: CGSize) {
        // 先清理旧资源（cleanup 自身会加锁）
        cleanup()

        let safeSize = initialSize.width > 0 && initialSize.height > 0 ? initialSize : CGSize(width: 360, height: 640)

        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.frame = CGRect(origin: .zero, size: safeSize)

        let renderView = UIView(frame: CGRect(origin: .zero, size: safeSize))
        renderView.layer.addSublayer(displayLayer)
        renderView.isUserInteractionEnabled = false
        renderView.backgroundColor = .clear
        renderView.contentMode = .scaleAspectFill
        renderView.alpha = 0.01  // 几乎不可见但系统认为可见，PiP 需要

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(renderView)
        } else if let window = UIApplication.shared.windows.first {
            window.addSubview(renderView)
        }

        var newController: AVPictureInPictureController?
        var didSetup = false
        if AVPictureInPictureController.isPictureInPictureSupported() {
            if #available(iOS 15.0, *) {
                let contentSource = AVPictureInPictureController.ContentSource(
                    sampleBufferDisplayLayer: displayLayer,
                    playbackDelegate: self
                )
                let controller = AVPictureInPictureController(contentSource: contentSource)
                controller?.delegate = self
                controller?.canStartPictureInPictureAutomaticallyFromInline = true
                newController = controller
                didSetup = true
                print("[PiP] Controller created, isPictureInPicturePossible: \(controller?.isPictureInPicturePossible ?? false)")
            } else {
                // iOS 15 以下不支持 SampleBuffer 模式，移除已添加的视图
                renderView.removeFromSuperview()
                return
            }
        } else {
            renderView.removeFromSuperview()
            print("[PiP] Picture in Picture not supported on this device")
            return
        }

        // 仅在锁内更新可变属性
        lock.lock()
        self.videoSize = initialSize
        self.isInCall = true
        self.sampleBufferDisplayLayer = displayLayer
        self.pipRenderView = renderView
        self.pipController = newController
        self.isSetup = didSetup
        lock.unlock()
    }
    
    /// 通话结束，清理画中画
    func endCall() {
        // 锁内更新状态并快照 controller，再到锁外调用外部 API
        lock.lock()
        isInCall = false
        let controller = pipController
        lock.unlock()

        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
        }
        cleanup()
    }
    
    /// 手动启动画中画（必须在 App 前台时调用）
    func start() {
        // 在锁内读取状态快照，避免持锁调用外部 API
        lock.lock()
        let setupReady = isSetup
        let inCall = isInCall
        let controller = pipController
        let hasFrames = hasEnqueuedFrames
        isPlaying = true
        lock.unlock()

        guard setupReady, inCall else {
            print("[PiP] Cannot start: isSetup=\(setupReady), isInCall=\(inCall)")
            return
        }
        if controller?.isPictureInPicturePossible == true {
            controller?.startPictureInPicture()
            print("[PiP] startPictureInPicture called")
        } else {
            print("[PiP] Cannot start: isPictureInPicturePossible=false")
            if hasFrames {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.lock.lock()
                    let stillInCall = self.isInCall
                    let retryController = self.pipController
                    self.lock.unlock()
                    guard stillInCall else { return }
                    if retryController?.isPictureInPicturePossible == true {
                        retryController?.startPictureInPicture()
                        print("[PiP] Retry: startPictureInPicture called")
                    }
                }
            }
        }
    }
    
    /// 停止画中画
    func stop() {
        lock.lock()
        let controller = pipController
        lock.unlock()
        controller?.stopPictureInPicture()
    }
    
    /// 清理资源
    func cleanup() {
        // 锁内重置属性，锁外执行 UI 移除
        lock.lock()
        pipController = nil
        sampleBufferDisplayLayer = nil
        let viewToRemove = pipRenderView
        pipRenderView = nil
        isSetup = false
        hasEnqueuedFrames = false
        lastEnqueuedTimestamp = .zero
        lock.unlock()

        if let viewToRemove = viewToRemove {
            if Thread.isMainThread {
                viewToRemove.removeFromSuperview()
            } else {
                DispatchQueue.main.async {
                    viewToRemove.removeFromSuperview()
                }
            }
        }
    }
    
    /// 接收视频帧（由 AgoraVideoFrameDelegate 回调送入，可能在后台线程）
    func enqueueVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // 锁内取出 displayLayer 并更新时间戳，避免与 cleanup/setup 竞争
        lock.lock()
        guard let displayLayer = sampleBufferDisplayLayer else {
            lock.unlock()
            return
        }
        let safeTimestamp: CMTime
        if timestamp <= lastEnqueuedTimestamp {
            safeTimestamp = CMTimeAdd(lastEnqueuedTimestamp, CMTime(value: 1, timescale: 30))
        } else {
            safeTimestamp = timestamp
        }
        lastEnqueuedTimestamp = safeTimestamp
        let isFirstFrame = !hasEnqueuedFrames
        lock.unlock()

        // 以下都是基于本地快照变量，可在锁外执行
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
            if isFirstFrame {
                lock.lock()
                hasEnqueuedFrames = true
                lock.unlock()
                print("[PiP] First frame enqueued")
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
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        lock.lock()
        let inCall = isInCall
        lock.unlock()
        print("[PiP] Restore user interface requested, isInCall=\(inCall)")
        if !inCall {
            // 通话已结束，不需要恢复界面，直接停止画中画
            pictureInPictureController.stopPictureInPicture()
            completionHandler(false)
        } else {
            completionHandler(true)
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate (iOS 15+)
@available(iOS 15.0, *)
extension PictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        lock.lock()
        isPlaying = playing
        lock.unlock()
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        lock.lock()
        let playing = isPlaying
        lock.unlock()
        return !playing
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) { }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let pipWillStart = Notification.Name("pipWillStart")
    static let pipDidStop = Notification.Name("pipDidStop")
}
