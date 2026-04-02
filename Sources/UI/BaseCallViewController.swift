//
//  BaseCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import UIKit

/// 通话界面基类，子类可继承并重写方法来定制 UI
open class BaseCallViewController: UIViewController, CallUIDelegate, FloatingWindowCompatible {
    
    // MARK: - 公共属性
    public let callManager = CallManager.shared
    public var callType: CallType? {
        return callManager.getCurrentCallType
    }
    public var remoteUserId: String? {
        return callManager.getCurrentRemoteUserId
    }
    
    // 基础 UI 组件（子类可访问和修改）
    public let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    
    public let durationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .lightGray
        return label
    }()
    
    public let muteAudioButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        btn.setImage(UIImage(systemName: "mic.slash.fill"), for: .selected)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    public let muteVideoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "video.fill"), for: .normal)
        btn.setImage(UIImage(systemName: "video.slash.fill"), for: .selected)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    public let speakerButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "speaker.wave.1.fill"), for: .normal)
        btn.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .selected)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    public let switchCameraButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "camera.rotate.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    public let endCallButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .systemRed
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    public let acceptCallButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "phone.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .systemGreen
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    public let rejectCallButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .systemRed
        btn.layer.cornerRadius = 30
        return btn
    }()
    
    // 控制按钮容器（子类可替换布局）
    public let controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.distribution = .equalSpacing
        return stack
    }()
    
    // 是否启用画中画
    private var isPictureInPictureActive = true
    
    // MARK: - 生命周期
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        callManager.uiDelegate = self
        setupBaseUI()
        setupActions()
        setupPictureInPicture()
        updateUIForState(callManager.currentState)
        
    }
    
    // MARK: - UI 设置（子类可重写以调整布局）
    open func setupBaseUI() {
        // 将控制按钮添加到 stack
        controlStackView.addArrangedSubview(muteAudioButton)
        controlStackView.addArrangedSubview(muteVideoButton)
        controlStackView.addArrangedSubview(speakerButton)
        controlStackView.addArrangedSubview(switchCameraButton)
        controlStackView.addArrangedSubview(endCallButton)
        view.addSubview(controlStackView)
        controlStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            controlStackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // 设置按钮大小
        let buttons = [muteAudioButton, muteVideoButton, speakerButton, switchCameraButton, endCallButton, acceptCallButton, rejectCallButton]
        buttons.forEach { button in
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 60),
                button.heightAnchor.constraint(equalToConstant: 60)
            ])
        }
        
        // 状态标签
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        // 时长标签
        view.addSubview(durationLabel)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            durationLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8)
        ])
        
        // 默认隐藏视频相关按钮（等子类根据 callType 显示）
        muteVideoButton.isHidden = true
        switchCameraButton.isHidden = true
        // 来电接听/拒绝按钮默认隐藏，它们会在收到来电时显示
        acceptCallButton.isHidden = true
        rejectCallButton.isHidden = true
        
        // 将接听/拒绝按钮也添加到 view，但不在 stack 中（由子类决定布局）
        view.addSubview(acceptCallButton)
        view.addSubview(rejectCallButton)
        acceptCallButton.translatesAutoresizingMaskIntoConstraints = false
        rejectCallButton.translatesAutoresizingMaskIntoConstraints = false
        // 简单放置在底部左右两侧，子类可重写
        NSLayoutConstraint.activate([
            acceptCallButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -50),
            acceptCallButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            rejectCallButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 50),
            rejectCallButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30)
        ])
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
    
    // 设置画中画事件
    open func setupPictureInPicture() {
        
        // 如果是视频通话，初始化画中画管理器
//            if callType == .video {
                // 假设本地视频视图为 localVideoView（子类应提供，这里用本地视图尺寸）
                let videoSize = localVideoView?.bounds.size ?? CGSize(width: 640, height: 480)
                PictureInPictureManager.shared.setup(initialSize: videoSize)
                
                // 监听画中画事件
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(pipWillStart),
                                                       name: .pipWillStart,
                                                       object: nil)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(pipDidStop),
                                                       name: .pipDidStop,
                                                       object: nil)
//            }
        // 监听 App 进入后台
           NotificationCenter.default.addObserver(self,
                                                  selector: #selector(applicationDidEnterBackground),
                                                  name: UIApplication.didEnterBackgroundNotification,
                                                  object: nil)
    }
    
    @objc private func applicationDidEnterBackground() {
        guard callType == .video,
              callManager.currentState == .connected,
              !isPictureInPictureActive else { return }
        // 启动画中画
        PictureInPictureManager.shared.start()
    }

    @objc private func pipWillStart() {
        isPictureInPictureActive = true
        // 隐藏本地视频视图（避免重复渲染）
        localVideoView?.isHidden = true
    }

    @objc private func pipDidStop() {
        isPictureInPictureActive = false
        // 恢复本地视频视图
        localVideoView?.isHidden = false
        // 注意：从画中画返回后，可能需要重新设置 Agora 的本地渲染视图
        // 如果之前移除了，需要重新调用 setupLocalVideoView
        if let localVideoView = localVideoView {
            callManager.setupLocalVideoView(localVideoView)
        }
    }

    // 子类需要提供 localVideoView
    open var localVideoView: UIView? {
        return nil
    }
    
    // MARK: - 控制方法（子类可重写或添加额外逻辑）
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
        dismiss(animated: true)
    }
    
    @objc open func acceptCall() {
        callManager.acceptCall()
        // 隐藏接听/拒绝按钮，显示控制按钮
        acceptCallButton.isHidden = true
        rejectCallButton.isHidden = true
        showControlButtons(true)
    }
    
    @objc open func rejectCall() {
        callManager.rejectCall()
        dismiss(animated: true)
    }
    
    /// 显示/隐藏通话控制按钮（静音、挂断等）
    open func showControlButtons(_ show: Bool) {
        controlStackView.isHidden = !show
    }
    
    // MARK: - 状态更新（子类可重写以自定义 UI）
    open func updateUIForState(_ state: CallState) {
        switch state {
        case .calling:
            statusLabel.text = "呼叫中..."
            durationLabel.text = ""
            showControlButtons(false)
            acceptCallButton.isHidden = true
            rejectCallButton.isHidden = true
        case .incoming:
            statusLabel.text = "来电..."
            durationLabel.text = ""
            showControlButtons(false)
            acceptCallButton.isHidden = false
            rejectCallButton.isHidden = false
        case .connecting:
            statusLabel.text = "连接中..."
            durationLabel.text = ""
            showControlButtons(false)
        case .connected:
            statusLabel.text = "通话中"
            showControlButtons(true)
            acceptCallButton.isHidden = true
            rejectCallButton.isHidden = true
        case .reconnecting:
            statusLabel.text = "重连中..."
        case .disconnected, .failed:
            statusLabel.text = state == .disconnected ? "通话结束" : "通话失败"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.dismiss(animated: true)
            }
        default:
            break
        }
    }
    
    open func updateDuration(_ duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - CallUIDelegate
    
    public func callStateDidChange(_ state: CallState) {
        DispatchQueue.main.async {
            self.updateUIForState(state)
        }
    }
    
    public func didConnect(withUid uid: UInt) {
        // 子类可重写
    }
    
    public func didDisconnect(error: Error?) {
        // 子类可重写
    }
    
    public func remoteUserDidJoin(uid: UInt, userId: String) {
        DispatchQueue.main.async {
            // 子类可重写，例如设置远端视频
        }
    }
    
    public func remoteUserDidLeave(uid: UInt, userId: String) {
        DispatchQueue.main.async {
            // 子类可重写
        }
    }
    
    public func didUpdateDuration(_ duration: TimeInterval) {
        DispatchQueue.main.async {
            self.updateDuration(duration)
        }
    }
    
    public func didReceiveIncomingCall(fromUserId: String, userName: String?, callType: CallType, channelName: String, token: String) {
        // 基类已经处理了状态，子类可以进一步定制
        DispatchQueue.main.async {
            self.updateUIForState(.incoming)
        }
    }
    
    public func didOccurError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "通话错误", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                self.dismiss(animated: true)
            })
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - FloatingWindowCompatible (悬浮窗支持)
    
    public var floatingWindowTitle: String {
        return remoteUserId ?? "通话中"
    }
    
    public var floatingWindowSubtitle: String? {
        return nil
    }
    
    public var isVideoCall: Bool {
        return callType == .video
    }
    
    public func getFloatingWindowVideoView() -> UIView? {
        return nil // 子类重写返回本地视频视图
    }
    
    public func restoreFromFloatingWindow(_ videoView: UIView?) {
        // 子类重写，将视频视图放回本地视图
    }
    
    public func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    public func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}

