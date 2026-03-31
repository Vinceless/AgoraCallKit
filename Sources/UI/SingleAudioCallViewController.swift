//
//  SingleAudioCallViewController.swift
//  CallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit
import CallCore

/// 单聊音频通话界面
class SingleAudioCallViewController: BaseCallViewController {
    
    // MARK: - UI 组件
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 75
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = .systemGray2
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textAlignment = .center
        label.textColor = .white
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioUI()
        setupRemoteUserInfo()
        
        // 音频通话不需要视频按钮，隐藏
        muteVideoButton.isHidden = true
        switchCameraButton.isHidden = true
    }
    
    private func setupAudioUI() {
        let stack = UIStackView(arrangedSubviews: [avatarImageView, nameLabel, statusLabel, durationLabel])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: 150),
            avatarImageView.heightAnchor.constraint(equalToConstant: 150),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50)
        ])
        
        // 调整状态标签和时长标签的颜色
        statusLabel.textColor = .lightGray
        durationLabel.textColor = .lightGray
    }
    
    private func setupRemoteUserInfo() {
        if let remoteUserId = remoteUserId {
            nameLabel.text = remoteUserId
        } else {
            nameLabel.text = "等待对方加入..."
        }
    }
    
    override func updateUIForState(_ state: CallState) {
        super.updateUIForState(state)
        switch state {
        case .calling:
            statusLabel.text = "呼叫中..."
        case .incoming:
            statusLabel.text = "来电..."
        case .connected:
            statusLabel.text = "通话中"
        case .disconnected:
            statusLabel.text = "通话结束"
        default:
            break
        }
    }
    
    override func remoteUserDidJoin(uid: UInt, userId: String) {
        super.remoteUserDidJoin(uid: uid, userId: userId)
        nameLabel.text = userId
        statusLabel.text = "通话中"
    }
    
    override func remoteUserDidLeave(uid: UInt, userId: String) {
        super.remoteUserDidLeave(uid: uid, userId: userId)
        nameLabel.text = "对方已离开"
        statusLabel.text = "通话结束"
    }
    
    // MARK: - 悬浮窗支持
    override var floatingWindowTitle: String {
        return remoteUserId ?? "音频通话"
    }
    
    override var floatingWindowSubtitle: String? {
        return "通话中"
    }
    
    override var isVideoCall: Bool {
        return false
    }
    
    override func getFloatingWindowVideoView() -> UIView? {
        return nil
    }
    
    override func restoreFromFloatingWindow(_ videoView: UIView?) {
        // 无视频视图
    }
    
    override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}
