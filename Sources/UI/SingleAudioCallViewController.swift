//
//  SingleAudioCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit

/// 单聊音频通话界面
open class SingleAudioCallViewController: BaseCallViewController {
    
    // MARK: - UI 组件
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = .systemGray2
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .center
        label.textColor = .white
        return label
    }()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioUI()
        setupRemoteUserInfo()
        
        // 音频通话不需要视频按钮，隐藏
        muteVideoButton.isHidden = true
        switchCameraButton.isHidden = true
    }
    
    private func setupAudioUI() {
        let stack = UIStackView(arrangedSubviews: [durationLabel, avatarImageView, nameLabel, statusLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        view.addSubview(stack)
        
        stack.setCustomSpacing(150, after: durationLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),
            nameLabel.heightAnchor.constraint(equalToConstant: 30),
            statusLabel.heightAnchor.constraint(equalToConstant: 15),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
    }
    
    private func setupRemoteUserInfo() {
        nameLabel.text = remoteUser?.name ?? "正在等待对方加入..."
    }
    
    open override func updateUIForState(_ state: CallState) {
        super.updateUIForState(state)
        switch state {
        case .calling:
            statusLabel.text = "呼叫中..."
        case .incoming:
            statusLabel.text = "对方邀请你语音通话..."
        case .connected:
            statusLabel.text = "通话中"
        case .disconnected:
            statusLabel.text = "通话结束"
        default:
            break
        }
    }
    
    open override func remoteUserDidJoin(_ user: CallUser) {
        super.remoteUserDidJoin(user)
        nameLabel.text = user.name
        statusLabel.text = "通话中"
    }
    
    open override func remoteUserDidLeave(_ user: CallUser) {
        super.remoteUserDidLeave(user)
        nameLabel.text = "对方已离开"
        statusLabel.text = "通话结束"
    }
    
    public override func didDisconnect(error: Error?) {
        super.didDisconnect(error: error)
        // 可选：显示提示后自动关闭
    }
    
    // MARK: - 悬浮窗支持
    public override var floatingWindowTitle: String {
        remoteUser?.name ?? "音频通话"
    }
    
    public override var floatingWindowSubtitle: String? {
        return "通话中"
    }
    
    public override var isVideoCall: Bool {
        return false
    }
    
    public override func getFloatingWindowVideoView() -> UIView? {
        return nil
    }
    
    public override func restoreFromFloatingWindow(_ videoView: UIView?) {
        // 无视频视图
    }
    
    public override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    public override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}
