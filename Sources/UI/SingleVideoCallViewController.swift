//
//  SingleVideoCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit

/// 单聊视频通话界面
open class SingleVideoCallViewController: BaseCallViewController {
    
    // MARK: - UI 组件
    private let remoteVideoView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    private let miniVideoView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    open override var localVideoView: UIView? {
        miniVideoView
    }
    
    private let remoteAvatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 50
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = .systemGray2
        iv.isHidden = true
        return iv
    }()
    
    private let remoteNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private var remoteUid: UInt?
    
    // MARK: - 生命周期
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoUI()
        setupRemoteUserInfo()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 调整本地视频小窗位置（可自定义）
        miniVideoView.frame = CGRect(
            x: view.bounds.width - 120 - 16,
            y: view.safeAreaInsets.top + 60,
            width: 120,
            height: 160
        )
        // 重新设置本地视频渲染，确保视图尺寸正确后初始化视频渲染器
        callManager.setupLocalVideoView(miniVideoView)
    }
    
    // MARK: - UI 设置
    private func setupVideoUI() {
        // 远端视频占满全屏
        view.insertSubview(remoteVideoView, at: 0)
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 本地视频小窗
        view.addSubview(miniVideoView)
        miniVideoView.translatesAutoresizingMaskIntoConstraints = false
        // 约束在 viewDidLayoutSubviews 中手动设置 frame，这里不做约束，以便更灵活
        
        // 远程信息视图
        let infoContainer = UIView()
        infoContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        infoContainer.layer.cornerRadius = 20
        infoContainer.clipsToBounds = true
        view.addSubview(infoContainer)
        infoContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            infoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            infoContainer.widthAnchor.constraint(equalToConstant: 200),
            infoContainer.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        infoContainer.addSubview(remoteAvatarImageView)
        infoContainer.addSubview(remoteNameLabel)
        remoteAvatarImageView.translatesAutoresizingMaskIntoConstraints = false
        remoteNameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remoteAvatarImageView.centerXAnchor.constraint(equalTo: infoContainer.centerXAnchor),
            remoteAvatarImageView.topAnchor.constraint(equalTo: infoContainer.topAnchor, constant: 16),
            remoteAvatarImageView.widthAnchor.constraint(equalToConstant: 50),
            remoteAvatarImageView.heightAnchor.constraint(equalToConstant: 50),
            remoteNameLabel.centerXAnchor.constraint(equalTo: infoContainer.centerXAnchor),
            remoteNameLabel.topAnchor.constraint(equalTo: remoteAvatarImageView.bottomAnchor, constant: 8),
            remoteNameLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 8),
            remoteNameLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -8)
        ])
        
        // 设置本地视频渲染
        callManager.setupLocalVideoView(miniVideoView)
    }
    
    private func setupRemoteUserInfo() {
        remoteNameLabel.text = remoteUser?.name ?? "等待对方加入..."
    }
    
    // MARK: - 重写父类方法（UI 更新）
    open override func updateUIForState(_ state: CallState) {
        super.updateUIForState(state)
        switch state {
        case .connected:
            // 连接成功后隐藏头像占位图，显示视频
            remoteAvatarImageView.isHidden = true
            // 连接成功后设置本地视频渲染
            callManager.setupLocalVideoView(miniVideoView)
        case .disconnected, .failed:
            remoteAvatarImageView.isHidden = false
        default:
            break
        }
    }
    
    // MARK: - 重写连接回调，设置本地视频
    open override func didConnect(withUser user: CallUser) {
        super.didConnect(withUser: user)
        // 通话连接后设置本地视频渲染
        callManager.setupLocalVideoView(miniVideoView)
        // 关键：启动本地视频预览
        callManager.startPreview()
    }
    
    open override func updateDuration(_ duration: TimeInterval) {
        super.updateDuration(duration)
        // 可自定义显示格式
    }
    
    // MARK: - CallUIDelegate 实现（部分重写）
    open override func remoteUserDidJoin(_ user: CallUser) {
        super.remoteUserDidJoin(user)
        remoteUid = user.uid
        callManager.setupRemoteVideoView(remoteVideoView, forUid: user.uid)
        remoteAvatarImageView.isHidden = true
        remoteNameLabel.text = user.name
    }
    
    open override func remoteUserDidLeave(_ user: CallUser) {
        super.remoteUserDidLeave(user)
        remoteAvatarImageView.isHidden = false
        remoteNameLabel.text = "对方已离开"
    }
    
    public override func didDisconnect(error: Error?) {
        super.didDisconnect(error: error)
        // 可选：显示提示后自动关闭
    }
    
    // MARK: - 悬浮窗支持
    public override var floatingWindowTitle: String {
        remoteUser?.name ?? "视频通话"
    }
    
    public override var floatingWindowSubtitle: String? {
        return "通话中"
    }
    
    public override var isVideoCall: Bool {
        return true
    }
    
    public override func getFloatingWindowVideoView() -> UIView? {
        return localVideoView
    }
    
    public override func restoreFromFloatingWindow(_ videoView: UIView?) {
        if let videoView = videoView {
            videoView.frame = miniVideoView.bounds
            videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            miniVideoView.addSubview(videoView)
        }
    }
    
    public override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    public override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}
