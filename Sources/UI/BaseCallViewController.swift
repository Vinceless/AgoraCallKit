//
//  BaseCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import UIKit

/// 通话界面基类，提供通用 UI 布局和状态管理
open class BaseCallViewController: UIViewController, CallUIDelegate, FloatingWindowCompatible {
    
    // MARK: - 公共属性
    public let callManager = CallManager.shared
    public var callType: CallType? { callManager.getCurrentCallType }
    public var remoteUser: CallUser? { callManager.getCurrentRemoteUser }
    
    // MARK: - UI 组件
    
    /// 顶部容器（用于放置缩小按钮和时长标签，保证居中对齐）
    public let topBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    /// 缩小按钮（悬浮窗入口）
    public let minimizeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.isHidden = true
        return btn
    }()
    
    /// 通话时长标签（顶部居中）
    public let durationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
//        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()
    
    /// 状态标签（呼叫中/通话中等）
    public let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        return label
    }()
    
    // 底部控制按钮（上图下文，图片 65x65，背景透明）
    public lazy var muteAudioButton: UIButton = createActionButton(imageName: "mic.fill", title: "静音")
    public lazy var muteVideoButton: UIButton = createActionButton(imageName: "video.fill", title: "视频")
    public lazy var speakerButton: UIButton = createActionButton(imageName: "speaker.wave.2.fill", title: "扬声器")
    public lazy var switchCameraButton: UIButton = createActionButton(imageName: "camera.rotate.fill", title: "切换")
    public lazy var endCallButton: UIButton = createActionButton(imageName: "phone.down.fill", title: "挂断", tintColor: .systemRed)
    public lazy var acceptCallButton: UIButton = createActionButton(imageName: "phone.fill", title: "接听", tintColor: .systemGreen)
    public lazy var rejectCallButton: UIButton = createActionButton(imageName: "phone.down.fill", title: "拒绝", tintColor: .systemRed)
    
    // 底部按钮容器
    public let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.distribution = .equalSpacing
        return stack
    }()
    
    public let controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        return stack
    }()
    
    public let callStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        return stack
    }()
    
    // 画中画相关
    private var isPictureInPictureActive = false
    private var isNotificationsRegistered = false
    
    // MARK: - 辅助方法：创建上图下文的圆形按钮（图片 65x65，背景透明）
    private func createActionButton(imageName: String, title: String, tintColor: UIColor = .white) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tintColor = tintColor
        btn.backgroundColor = .clear
        btn.layer.cornerRadius = 12
        btn.clipsToBounds = true
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: imageName)
            config.title = title
            config.imagePlacement = .top
            config.imagePadding = 10
            config.baseForegroundColor = tintColor
            config.baseBackgroundColor = .clear
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            btn.configuration = config
        } else {
            btn.setImage(UIImage(systemName: imageName), for: .normal)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 12)
            btn.imageView?.contentMode = .scaleAspectFit
            btn.imageEdgeInsets = UIEdgeInsets(top: -15, left: 0, bottom: 0, right: 0)
            btn.titleEdgeInsets = UIEdgeInsets(top: 55, left: -60, bottom: 0, right: 0)
            btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }
    
    // MARK: - 生命周期
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        callManager.uiDelegate = self
        setupBaseUI()
        setupActions()
        updateUIForState(callManager.currentState)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        registerNotifications()
    }
    
    // MARK: - UI 布局
    open func setupBaseUI() {
        // 顶部栏布局（缩小按钮左侧，时长标签居中）
        view.addSubview(topBarView)
        topBarView.addSubview(minimizeButton)
        topBarView.addSubview(durationLabel)
        
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 60),
            
            minimizeButton.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: 16),
            minimizeButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            minimizeButton.widthAnchor.constraint(equalToConstant: 40),
            minimizeButton.heightAnchor.constraint(equalToConstant: 40),
            
            durationLabel.centerXAnchor.constraint(equalTo: topBarView.centerXAnchor),
            durationLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            durationLabel.heightAnchor.constraint(equalToConstant: 30),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
        
        // 状态标签（默认放在顶部栏下方，子类可重写位置）
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: topBarView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        // 底部控制按钮
        controlStackView.addArrangedSubview(muteAudioButton)
        controlStackView.addArrangedSubview(endCallButton)
        controlStackView.addArrangedSubview(speakerButton)
        controlStackView.addArrangedSubview(muteVideoButton)
        
        callStackView.addArrangedSubview(rejectCallButton)
        callStackView.addArrangedSubview(acceptCallButton)
        callStackView.addArrangedSubview(switchCameraButton)
        
        view.addSubview(actionStackView)
        actionStackView.addArrangedSubview(controlStackView)
        actionStackView.addArrangedSubview(callStackView)
        
        actionStackView.translatesAutoresizingMaskIntoConstraints = false
        controlStackView.translatesAutoresizingMaskIntoConstraints = false
        callStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            actionStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            controlStackView.heightAnchor.constraint(equalToConstant: 90),
            callStackView.heightAnchor.constraint(equalToConstant: 90),
        ])
        
        let buttons = [muteAudioButton, muteVideoButton, speakerButton, endCallButton, switchCameraButton, acceptCallButton, rejectCallButton]
        buttons.forEach { button in
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.required, for: .vertical)
        }
        
        // 初始隐藏视频相关按钮
        muteVideoButton.isHidden = true
        switchCameraButton.isHidden = true
        acceptCallButton.isHidden = true
        rejectCallButton.isHidden = true
        
        // 添加缩小按钮点击事件
        minimizeButton.addTarget(self, action: #selector(minimizeTapped), for: .touchUpInside)
    }
    
    open func setupActions() {
        muteAudioButton.addTarget(self, action: #selector(toggleAudio), for: .touchUpInside)
        muteVideoButton.addTarget(self, action: #selector(toggleVideo), for: .touchUpInside)
        speakerButton.addTarget(self, action: #selector(toggleSpeaker), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        endCallButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        acceptCallButton.addTarget(self, action: #selector(acceptCall), for: .touchUpInside)
        rejectCallButton.addTarget(self, action: #selector(rejectCall), for: .touchUpInside)
    }
    
    @objc private func minimizeTapped() {
        FloatingWindowManager.shared.showFloatingWindow(from: self)
        dismiss(animated: true)
    }
    
    // MARK: - 通知注册（画中画、前后台）
    private func registerNotifications() {
        guard !isNotificationsRegistered else { return }
        isNotificationsRegistered = true
        if callType == .video {
            NotificationCenter.default.addObserver(self, selector: #selector(pipWillStart), name: .pipWillStart, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(pipDidStop), name: .pipDidStop, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func initPictureInPicture() {
        guard callType == .video else { return }
        let videoSize = remoteVideoView?.bounds.size ?? localVideoView?.bounds.size ?? CGSize(width: 360, height: 640)
        PictureInPictureManager.shared.setup(initialSize: videoSize)
        callManager.engine.startPiPCapturer(remoteVideoView: remoteVideoView)
    }
    
    @objc private func applicationDidEnterBackground() {
        guard callType == .video, !isPictureInPictureActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            PictureInPictureManager.shared.start()
        }
    }
    
    @objc private func applicationWillEnterForeground() {
        if isPictureInPictureActive {
            PictureInPictureManager.shared.stop()
        }
    }
    
    @objc private func pipWillStart() {
        isPictureInPictureActive = true
        localVideoView?.isHidden = true
    }
    
    @objc private func pipDidStop() {
        isPictureInPictureActive = false
        localVideoView?.isHidden = false
        restoreVideoViewsAfterPip()
    }
    
    /// 本地视频视图（子类重写）
    open var localVideoView: UIView? { nil }
    /// 远端视频视图（子类重写）
    open var remoteVideoView: UIView? { nil }
    /// 画中画停止后恢复视频渲染（子类重写）
    open func restoreVideoViewsAfterPip() { }
    
    // MARK: - 控制方法
    @objc open func toggleAudio() {
        let newState = !muteAudioButton.isSelected
        callManager.muteAudio(newState)
        muteAudioButton.isSelected = newState
    }
    
    @objc open func toggleVideo() {
        let newState = !muteVideoButton.isSelected
        callManager.muteVideo(newState)
        muteVideoButton.isSelected = newState
    }
    
    @objc open func toggleSpeaker() {
        let newState = !speakerButton.isSelected
        callManager.setSpeakerEnabled(newState)
        speakerButton.isSelected = newState
    }
    
    @objc open func switchCamera() {
        callManager.switchCamera()
    }
    
    @objc open func endCall() {
        callManager.hangUp()
        if callType == .video {
            callManager.engine.stopPiPCapturer()
            PictureInPictureManager.shared.endCall()
        }
        dismiss(animated: true)
    }
    
    @objc open func acceptCall() {
        callManager.acceptCall()
        acceptCallButton.isHidden = true
        rejectCallButton.isHidden = true
        showControlButtons(true)
    }
    
    @objc open func rejectCall() {
        callManager.rejectCall()
        dismiss(animated: true)
    }
    
    open func showControlButtons(_ show: Bool) {
        controlStackView.isHidden = !show
    }
    
    // MARK: - 状态更新
    open func updateUIForState(_ state: CallState) {
        switch state {
        case .calling:
            statusLabel.text = "呼叫中..."
            durationLabel.isHidden = true
            showControlButtons(false)
            acceptCallButton.isHidden = true
            rejectCallButton.isHidden = true
        case .incoming:
            statusLabel.text = "来电..."
            durationLabel.isHidden = true
            showControlButtons(false)
            acceptCallButton.isHidden = false
            rejectCallButton.isHidden = false
        case .connecting:
            statusLabel.text = "连接中..."
            durationLabel.isHidden = true
            showControlButtons(false)
        case .connected:
            statusLabel.text = "通话中"
            durationLabel.isHidden = false
            showControlButtons(true)
            acceptCallButton.isHidden = true
            rejectCallButton.isHidden = true
        case .reconnecting:
            statusLabel.text = "重连中..."
            durationLabel.isHidden = false
        case .disconnected, .failed:
            statusLabel.text = state == .disconnected ? "通话结束" : "通话失败"
            durationLabel.isHidden = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.dismiss(animated: true)
            }
        default:
            break
        }
        minimizeButton.isHidden = (state != .connected)
    }
    
    open func updateDuration(_ duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - CallUIDelegate
    public func callStateDidChange(_ state: CallState) {
        DispatchQueue.main.async { self.updateUIForState(state) }
    }
    
    open func didConnect(withUser user: CallUser) {
        if callType == .video { initPictureInPicture() }
    }
    
    open func didDisconnect(error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            IncomingCallManager.shared.hide()
            self.statusLabel.text = error == nil ? "通话结束" : "通话失败"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.dismiss(animated: true) }
        }
        if callType == .video {
            callManager.engine.stopPiPCapturer()
            PictureInPictureManager.shared.endCall()
        }
    }
    
    open func remoteUserDidJoin(_ user: CallUser) { }
    open func remoteUserDidLeave(_ user: CallUser) { }
    
    public func didUpdateDuration(_ duration: TimeInterval) {
        DispatchQueue.main.async { self.updateDuration(duration) }
    }
    
    public func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {
        DispatchQueue.main.async { self.updateUIForState(.incoming) }
    }
    
    public func didOccurError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "通话错误", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in self.dismiss(animated: true) })
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - FloatingWindowCompatible 默认实现
    public var floatingWindowTitle: String { remoteUser?.name ?? "通话中" }
    public var floatingWindowSubtitle: String? { nil }
    public var isVideoCall: Bool { callType == .video }
    open func getFloatingWindowVideoView() -> UIView? { nil }
    open func bindRemoteVideoToFloatingView(_ view: UIView) { }
    open func restoreFromFloatingWindow(_ videoView: UIView?) { }
    open func endCallFromFloatingWindow() { callManager.hangUp() }
    open func getCurrentCallDuration() -> TimeInterval { callManager.getCurrentDuration() }
}
