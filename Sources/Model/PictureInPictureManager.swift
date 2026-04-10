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
    
    private override init() {}
    
    /// 初始化画中画视图（应在通话开始后调用，传入视频渲染视图的尺寸）
    func setup(initialSize: CGSize) {
        videoSize = initialSize
        
        // 先清理旧的
        cleanup()
        
        // 创建 AVSampleBufferDisplayLayer 用于渲染视频帧
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.frame = CGRect(origin: .zero, size: initialSize)
        self.sampleBufferDisplayLayer = displayLayer
        
        // 创建一个 view 来持有 displayLayer，并将其添加到当前 key window 上
        // AVPictureInPictureController 要求 layer 必须在一个 window 的 view 层级中
        let renderView = UIView(frame: CGRect(origin: .zero, size: initialSize))
        renderView.layer.addSublayer(displayLayer)
        renderView.alpha = 0.01  // 几乎不可见，但仍在视图层级中
        renderView.isUserInteractionEnabled = false
        renderView.backgroundColor = .black
        pipRenderView = renderView
        
        // 将 renderView 添加到 key window
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(renderView)
            print("[PiP] renderView added to key window")
        } else if let window = UIApplication.shared.windows.first {
            window.addSubview(renderView)
            print("[PiP] renderView added to first window")
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
                print("[PiP] Controller created with ContentSource (iOS 15+)")
            } else {
                // iOS 14: 不支持 AVSampleBufferDisplayLayer 的 PiP
                // 需要使用 AVPlayerLayer，但无法直接推送原始帧
                print("[PiP] Warning: iOS 14 does not support AVSampleBufferDisplayLayer PiP")
                return
            }
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            }
        } else {
            print("[PiP] Error: Picture in Picture not supported on this device")
        }
    }
    
    /// 启动画中画
    func start() {
        guard let controller = pipController else {
            print("[PiP] Error: pipController is nil, setup not called or failed")
            return
        }
        
        isPlaying = true
        print("[PiP] Attempting to start, isPictureInPicturePossible = \(controller.isPictureInPicturePossible)")
        
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
        } else {
            // 可能需要等待视频帧到达后才能启动
            print("[PiP] Not possible yet, retrying in 0.5s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let controller = self.pipController else { return }
                print("[PiP] Retry: isPictureInPicturePossible = \(controller.isPictureInPicturePossible)")
                if controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("[PiP] Final retry: isPictureInPicturePossible = \(controller.isPictureInPicturePossible)")
                        if controller.isPictureInPicturePossible {
                            controller.startPictureInPicture()
                        } else {
                            print("[PiP] Failed: isPictureInPicturePossible still false after retries")
                        }
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
    }
    
    /// 接收视频帧（由 Agora 回调调用）
    func enqueueVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let displayLayer = sampleBufferDisplayLayer else { return }
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
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
    
    /// PiP 控制器请求开始或暂停播放
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        isPlaying = playing
        print("[PiP] setPlaying: \(playing)")
    }
    
    /// 返回可播放的时间范围（直播流返回无限范围）
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // 实时通话，使用无限时间范围
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    /// 返回当前是否暂停
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return !isPlaying
    }
    
    /// PiP 窗口大小变化回调
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        print("[PiP] Render size changed: \(newRenderSize.width)x\(newRenderSize.height)")
    }
    
    /// 快进/快退（实时通话不需要实现，空操作即可）
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension Notification.Name {
    static let pipWillStart = Notification.Name("pipWillStart")
    static let pipDidStop = Notification.Name("pipDidStop")
    static let needRestoreFloatingWindow = Notification.Name("needRestoreFloatingWindow")
}
