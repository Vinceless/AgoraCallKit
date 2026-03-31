//
//  BaseCallViewController.swift
//  CallCore
//
//  Created by Vince on 2021/3/29.
//

import UIKit

/// 通话界面基类，子类可继承并重写方法来定制 UI
open class BaseCallViewController: UIViewController {
    
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
    
    // MARK: - 生命周期
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        callManager.uiDelegate = self
        setupBaseUI()
        setupActions()
        updateUIForState(callManager.currentState)
    }
    
    open func setupBaseUI() {
        // 默认将所有控制按钮放在底部水平排列
        let stack = UIStackView(arrangedSubviews: [muteAudioButton, muteVideoButton, speakerButton, switchCameraButton, endCallButton])
        stack.axis = .horizontal
        stack.spacing = 20
        stack.distribution = .equalSpacing
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            stack.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // 状态标签
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        view.addSubview(durationLabel)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            durationLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8)
        ])
        
        // 默认隐藏视频相关按钮（等子类根据 callType 显示）
        muteVideoButton.isHidden = true
        switchCameraButton.isHidden = true
        // 来电接听/拒绝按钮默认隐藏
        acceptCallButton.isHidden = true
        rejectCallButton.isHidden = true
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
    
    // MARK: - Actions
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
        // 切换按钮显示：隐藏接听/拒绝，显示正常控制按钮
        acceptCallButton.isHidden = true
        rejectCallButton.isHidden = true
        showControlButtons(true)
    }
    
    @objc open func rejectCall() {
        callManager.rejectCall()
        dismiss(animated: true)
    }
    
    // 辅助方法：显示/隐藏控制按钮（静音、挂断等）
    open func showControlButtons(_ show: Bool) {
        muteAudioButton.isHidden = !show
        muteVideoButton.isHidden = !(show && callType == .video)
        speakerButton.isHidden = !show
        switchCameraButton.isHidden = !(show && callType == .video)
        endCallButton.isHidden = !show
    }
    
    // MARK: - 子类可重写的状态更新方法
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
            // 将接听/拒绝按钮放在底部（子类可调整位置）
            // 这里简单地将它们添加到 stack 中，实际可能需要重新布局
            // 我们暂时不自动添加，由子类在 setupBaseUI 中处理
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
}

// MARK: - CallUIDelegate
extension BaseCallViewController: CallUIDelegate {
    public func callStateDidChange(_ state: CallState) {
        DispatchQueue.main.async {
            self.updateUIForState(state)
        }
    }
    
    public func didConnect(withUid uid: UInt) {
        // 可做额外处理
    }
    
    public func didDisconnect(error: Error?) {
        DispatchQueue.main.async {
            // 界面会由状态变化自动关闭
        }
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
        DispatchQueue.main.async {
            // 这个回调通常由 CallManager 触发，UI 会弹出此界面
            // 基类已经处理了状态，子类可以展示自定义来电界面
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
}
