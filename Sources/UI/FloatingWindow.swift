//
//  FloatingWindow.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import UIKit

// MARK: - 悬浮窗兼容协议
/// 通话页面需实现此协议以支持悬浮窗功能
public protocol FloatingWindowCompatible: UIViewController {
    /// 悬浮窗标题
    var floatingWindowTitle: String { get }
    /// 悬浮窗副标题（可选）
    var floatingWindowSubtitle: String? { get }
    /// 是否为视频通话
    var isVideoCall: Bool { get }
    /// 返回一个用于悬浮窗展示的新视图（由调用方创建并绑定视频）
    func getFloatingWindowVideoView() -> UIView?
    /// 将远端视频绑定到指定视图上
    func bindRemoteVideoToFloatingView(_ view: UIView)
    /// 从悬浮窗恢复时调用，将视频视图归还原位
    func restoreFromFloatingWindow(_ videoView: UIView?)
    /// 悬浮窗结束通话
    func endCallFromFloatingWindow()
    /// 获取当前通话时长（秒）
    func getCurrentCallDuration() -> TimeInterval
}

public extension FloatingWindowCompatible {
    var floatingWindowSubtitle: String? { nil }
    func floatingWindowWillAppear() {}
    func floatingWindowDidDisappear() {}
    func floatingWindowDidTap() {}
}

// MARK: - 悬浮窗管理器
/// 负责悬浮窗的显示、隐藏和恢复
public class FloatingWindowManager {
    public static let shared = FloatingWindowManager()
    
    private var floatingWindow: FloatingCallWindow?
    private weak var currentViewController: FloatingWindowCompatible?
    
    /// 显示悬浮窗
    /// - Parameter viewController: 当前通话控制器（需遵循 FloatingWindowCompatible）
    public func showFloatingWindow(from viewController: FloatingWindowCompatible) {
        if let existing = floatingWindow {
            existing.hide()
        }
        currentViewController = viewController
        floatingWindow = FloatingCallWindow()
        _ = floatingWindow?.view
        floatingWindow?.configure(with: viewController)
        floatingWindow?.show()
        viewController.floatingWindowWillAppear()
    }
    
    /// 隐藏悬浮窗
    public func hideFloatingWindow() {
        currentViewController?.floatingWindowDidDisappear()
        floatingWindow?.hide()
        floatingWindow = nil
        currentViewController = nil
    }
    
    /// 从悬浮窗恢复到全屏
    @discardableResult
    public func restoreFromFloatingWindow() -> FloatingWindowCompatible? {
        guard let vc = currentViewController else { return nil }
        // 直接移除悬浮窗并present
        floatingWindow?.view.removeFromSuperview()
        let videoView = floatingWindow?.getAndClearVideoView()
        vc.restoreFromFloatingWindow(videoView)
        hideFloatingWindow()
        // 重新 present VC
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(vc, animated: true) {
                    vc.onRestoredFromFloatingWindow()
                }
            }
        }
        return vc
    }
    
    /// 悬浮窗是否正在显示
    public func isShowing() -> Bool {
        floatingWindow != nil
    }
}

// MARK: - 悬浮窗视图控制器
/// - 音频模式(80x80)：绿色圆形通话按钮，未接通显示"连接中..."，接通后显示通话时长
/// - 视频模式(110x200)：全屏显示对方视频
/// - 点击窗口恢复全屏
class FloatingCallWindow: UIViewController {
    private var containerView: UIView!
    private var contentViewContainer: UIView!
    private var videoView: UIView!
    private var audioView: UIView!
    private var durationLabel: UILabel!
    private var callButton: UIButton!
    private var statusLabel: UILabel!
    
    private weak var originalViewController: FloatingWindowCompatible?
    private var panGesture: UIPanGestureRecognizer?
    private var durationTimer: Timer?
    private var isVideoMode = false
    private var savedVideoView: UIView?
    
    private var callManager: CallManager? { CallManager.shared }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        startDurationTimer()
        registerCallStateNotification()
    }
    
    deinit {
        durationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 监听通话状态变化，通话结束时自动隐藏悬浮窗
    private func registerCallStateNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCallStateChanged),
            name: .callStateChanged,
            object: nil
        )
    }
    
    @objc private func handleCallStateChanged(_ notification: Notification) {
        guard let state = notification.object as? CallState else { return }
        if state == .idle || state == .disconnected {
            // 通话已结束，隐藏悬浮窗
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.view.removeFromSuperview()
                FloatingWindowManager.shared.hideFloatingWindow()
            }
        }
    }
    
    func configure(with viewController: FloatingWindowCompatible) {
        originalViewController = viewController
        isVideoMode = viewController.isVideoCall
        
        updateLayoutForMode()
        
        if isVideoMode {
            if let floatingVideoView = viewController.getFloatingWindowVideoView() {
                setupVideoContent(floatingVideoView)
                viewController.bindRemoteVideoToFloatingView(floatingVideoView)
            }
            audioView.isHidden = true
            videoView.isHidden = false
        } else {
            setupAudioContent()
            videoView.isHidden = true
            audioView.isHidden = false
            updateAudioContent()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        // 阴影容器（不裁切，只负责阴影）
        containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowOffset = .zero
        containerView.layer.shadowRadius = 6
        view.addSubview(containerView)
        
        // 内容容器（裁切圆角）
        contentViewContainer = UIView()
        contentViewContainer.backgroundColor = .white
        contentViewContainer.layer.cornerRadius = 12
        contentViewContainer.layer.masksToBounds = true
        containerView.addSubview(contentViewContainer)
        
        // 视频内容视图
        videoView = UIView()
        videoView.backgroundColor = .black
        contentViewContainer.addSubview(videoView)
        
        // 音频内容视图（白色背景）
        audioView = UIView()
        audioView.backgroundColor = .white
        contentViewContainer.addSubview(audioView)
        
        // 通话按钮（绿色图标）
        let greenColor = UIColor(red: 0.13, green: 0.59, blue: 0.33, alpha: 1.0)
        callButton = UIButton(type: .system)
        callButton.setImage(UIImage(systemName: "phone.fill"), for: .normal)
        callButton.tintColor = greenColor
        callButton.backgroundColor = .clear
        callButton.addTarget(self, action: #selector(callButtonTapped), for: .touchUpInside)
        
        // 通话时长标签（绿色文字）
        durationLabel = UILabel()
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = greenColor
        durationLabel.textAlignment = .center
        durationLabel.backgroundColor = .clear
        durationLabel.clipsToBounds = true
        
        // 状态标签（连接中，绿色文字）
        statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.textColor = greenColor
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = .clear
        statusLabel.clipsToBounds = true
        
        audioView.addSubview(callButton)
        audioView.addSubview(durationLabel)
        audioView.addSubview(statusLabel)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentViewContainer.translatesAutoresizingMaskIntoConstraints = false
        videoView.translatesAutoresizingMaskIntoConstraints = false
        audioView.translatesAutoresizingMaskIntoConstraints = false
        callButton.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func updateLayoutForMode() {
        let size = isVideoMode ? CGSize(width: 110, height: 200) : CGSize(width: 70, height: 70)
        
        containerView.layer.cornerRadius = 12
        
        // 移除旧约束
        containerView.constraints.forEach { $0.isActive = false }
        containerView.removeConstraints(containerView.constraints)
        view.constraints.forEach { $0.isActive = false }
        view.removeConstraints(view.constraints)
        
        // containerView 约束
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: size.width),
            containerView.heightAnchor.constraint(equalToConstant: size.height),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // contentViewContainer 铺满 containerView
        contentViewContainer.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        contentViewContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        contentViewContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        contentViewContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        
        if isVideoMode {
            // 视频模式背景为黑色
            contentViewContainer.backgroundColor = .black
            videoView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
            videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
            videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
            audioView.isHidden = true
        } else {
            // 音频模式背景为白色
            contentViewContainer.backgroundColor = .white
            audioView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
            audioView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            audioView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
            audioView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
            
            let buttonSize: CGFloat = 35
            NSLayoutConstraint.activate([
                callButton.centerXAnchor.constraint(equalTo: audioView.centerXAnchor),
                callButton.centerYAnchor.constraint(equalTo: audioView.centerYAnchor, constant: -10),
                callButton.widthAnchor.constraint(equalToConstant: buttonSize),
                callButton.heightAnchor.constraint(equalToConstant: buttonSize),
                
                durationLabel.bottomAnchor.constraint(equalTo: audioView.bottomAnchor, constant: -8),
                durationLabel.centerXAnchor.constraint(equalTo: audioView.centerXAnchor),
                durationLabel.heightAnchor.constraint(equalToConstant: 16),
                
                statusLabel.centerXAnchor.constraint(equalTo: audioView.centerXAnchor),
                statusLabel.centerYAnchor.constraint(equalTo: audioView.centerYAnchor, constant: -10)
            ])
            videoView.isHidden = true
        }
    }
    
    private func setupVideoContent(_ video: UIView) {
        savedVideoView = video
        videoView.subviews.forEach { $0.removeFromSuperview() }
        // 使用 AutoresizingMask 让视频视图自动填充 videoView
        video.translatesAutoresizingMaskIntoConstraints = false
        videoView.addSubview(video)
        NSLayoutConstraint.activate([
            video.topAnchor.constraint(equalTo: videoView.topAnchor),
            video.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            video.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            video.bottomAnchor.constraint(equalTo: videoView.bottomAnchor)
        ])
    }
    
    private func setupAudioContent() {
        // 音频模式不需要额外设置
    }
    
    private func updateAudioContent() {
        let duration = originalViewController?.getCurrentCallDuration() ?? 0
        if duration > 0 {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            durationLabel.text = String(format: " %02d:%02d ", minutes, seconds)
            durationLabel.isHidden = false
            statusLabel.isHidden = true
        } else {
            statusLabel.text = " 连接中 "
            statusLabel.isHidden = false
            durationLabel.isHidden = true
        }
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        contentViewContainer.addGestureRecognizer(panGesture!)
        let tap = UITapGestureRecognizer(target: self, action: #selector(restoreToFullscreenView))
        contentViewContainer.addGestureRecognizer(tap)
    }
    
    func show() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        
        let size = isVideoMode ? CGSize(width: 110, height: 200) : CGSize(width: 80, height: 80)
        view.frame = CGRect(x: keyWindow.bounds.width - size.width - 16, y: 100, width: size.width, height: size.height)
        keyWindow.addSubview(view)
        
        view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.view.transform = .identity
        }
    }
    
    func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.view.alpha = 0
            self.view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }) { _ in
            self.view.removeFromSuperview()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = view.superview else { return }
        let translation = gesture.translation(in: superview)
        switch gesture.state {
        case .changed:
            view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
        case .ended:
            let finalX: CGFloat
            if view.center.x < superview.bounds.width / 2 {
                finalX = view.frame.width / 2 + 10
            } else {
                finalX = superview.bounds.width - view.frame.width / 2 - 10
            }
            UIView.animate(withDuration: 0.3) {
                self.view.center = CGPoint(x: finalX, y: self.view.center.y)
            }
        default: break
        }
    }
    
    @objc private func restoreToFullscreenView() {
        // 如果通话已结束，不恢复全屏，直接隐藏
        let callState = CallManager.shared.currentState
        if callState == .idle || callState == .disconnected {
            view.removeFromSuperview()
            FloatingWindowManager.shared.hideFloatingWindow()
            return
        }
        guard let vc = originalViewController else { return }
        // 获取视频视图引用
        let videoView = getAndClearVideoView()
        // 立即移除悬浮窗视图
        view.removeFromSuperview()
        // 通知 VC 恢复
        vc.restoreFromFloatingWindow(videoView)
        // 重新 present VC
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(vc, animated: true) {
                    vc.onRestoredFromFloatingWindow()
                }
            }
        }
    }
    
    /// 获取并清除视频视图（恢复时调用）
    func getAndClearVideoView() -> UIView? {
        let view = savedVideoView
        savedVideoView = nil
        return view
    }
    
    @objc private func callButtonTapped() {
        callManager?.acceptCall()
    }
    
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if self?.isVideoMode == false {
                self?.updateAudioContent()
            }
        }
    }
}

// MARK: - 通知扩展
public extension Notification.Name {
    static let needRestoreFloatingWindow = Notification.Name("needRestoreFloatingWindow")
    static let callStateChanged = Notification.Name("callStateChanged")
}
