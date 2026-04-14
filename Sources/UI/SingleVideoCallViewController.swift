//
//  SingleVideoCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit
import Kingfisher

/// 单聊视频通话界面
open class SingleVideoCallViewController: BaseCallViewController {
    
    // MARK: - UI 组件
    private let remoteVideoContainer: UIView = {
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
    
    open override var remoteVideoView: UIView? {
        remoteVideoContainer
    }
    
    /// 画中画停止后恢复远程视频渲染
    open override func restoreVideoViewsAfterPip() {
        super.restoreVideoViewsAfterPip()
        // 重新设置远程视频渲染视图
        if let uid = remoteUid {
            callManager.setupRemoteVideoView(remoteVideoContainer, forUid: uid)
        }
    }
    
    private let remoteAvatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 50
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = .systemGray2
        return iv
    }()
    
    private let remoteNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private var remoteUid: UInt?
    private var floatingVideoView: UIView?  // 悬浮窗专用的视频视图
    
    /// 远程信息容器（时长+头像+名字+状态），远端用户加入后隐藏
    private weak var infoContainer: UIView?
    
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
        view.insertSubview(remoteVideoContainer, at: 0)
        remoteVideoContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remoteVideoContainer.topAnchor.constraint(equalTo: view.topAnchor),
            remoteVideoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteVideoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteVideoContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 本地视频小窗（使用 frame 布局，不用 Auto Layout）
        view.addSubview(miniVideoView)
        
        // 远程信息容器（与音频通话一样的垂直布局）
        let infoContainer = UIStackView(arrangedSubviews: [remoteAvatarImageView, remoteNameLabel, statusLabel])
        infoContainer.axis = .vertical
        infoContainer.spacing = 12
        infoContainer.alignment = .center
        view.addSubview(infoContainer)
        infoContainer.translatesAutoresizingMaskIntoConstraints = false
        self.infoContainer = infoContainer
        
        NSLayoutConstraint.activate([
            remoteAvatarImageView.widthAnchor.constraint(equalToConstant: 100),
            remoteAvatarImageView.heightAnchor.constraint(equalToConstant: 100),
            remoteNameLabel.heightAnchor.constraint(equalToConstant: 30),
            statusLabel.heightAnchor.constraint(equalToConstant: 15),
            infoContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 180),
            infoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // 设置本地视频渲染
        callManager.setupLocalVideoView(miniVideoView)
    }
    
    private func setupRemoteUserInfo() {
        remoteNameLabel.text = remoteUser?.name ?? "等待对方加入..."
        if let avatar = remoteUser?.avatar, !avatar.isEmpty, let url = URL(string: avatar) {
            remoteAvatarImageView.kf.setImage(
                with: url,
                placeholder: UIImage(systemName: "person.circle.fill"),
                options: [.transition(.fade(0.3))]
            )
        }
    }
    
    // MARK: - 重写父类方法（UI 更新）
    open override func updateUIForState(_ state: CallState) {
        super.updateUIForState(state)
        switch state {
        case .calling:
            statusLabel.text = "呼叫中..."
        case .incoming:
            statusLabel.text = "对方邀请你视频通话..."
        case .connecting:
            statusLabel.text = "连接中..."
        case .connected:
            // 连接成功后设置本地视频渲染（头像等在远端用户加入时才隐藏）
            callManager.setupLocalVideoView(miniVideoView)
        case .disconnected, .failed:
            infoContainer?.isHidden = false
            remoteAvatarImageView.isHidden = false
        default:
            break
        }
    }
    
    // MARK: - 重写连接回调，设置本地视频
    open override func didJoinChannel(withUser user: CallUser) {
        super.didJoinChannel(withUser: user)
        print("[SingleVideo] didJoinChannel: miniVideoView.bounds=\(miniVideoView.bounds), window=\(miniVideoView.window != nil)")
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
        // 绑定到全屏视图
        callManager.setupRemoteVideoView(remoteVideoContainer, forUid: user.uid)
        // 如果悬浮窗存在，也绑定到悬浮窗视图
        if let floatingView = floatingVideoView {
            callManager.setupRemoteVideoView(floatingView, forUid: user.uid)
        }
        // 远端用户加入：隐藏信息容器（头像+名字+状态）
        infoContainer?.isHidden = true
        remoteAvatarImageView.isHidden = true
        remoteNameLabel.text = user.name
        statusLabel.text = "通话中"
    }
    
    open override func remoteUserDidLeave(_ user: CallUser) {
        super.remoteUserDidLeave(user)
        infoContainer?.isHidden = false
        remoteAvatarImageView.isHidden = false
        remoteNameLabel.text = "对方已离开"
        statusLabel.text = "通话结束"
    }
    
    public override func didDisconnect(error: Error?) {
        super.didDisconnect(error: error)
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
        // 确保远端用户已加入
        guard remoteUid != nil else { return nil }
        // 创建悬浮窗专用的视频视图（复用已有或新建）
        if floatingVideoView == nil {
            floatingVideoView = UIView()
            floatingVideoView?.backgroundColor = .black
            floatingVideoView?.frame = CGRect(x: 0, y: 0, width: 110, height: 200)
        }
        return floatingVideoView
    }
    
    public override func bindRemoteVideoToFloatingView(_ view: UIView) {
        // 将远端视频绑定到悬浮窗视图
        if let uid = remoteUid {
            callManager.setupRemoteVideoView(view, forUid: uid)
        }
    }
    
    /// 恢复时重新设置远端渲染
    public override func restoreFromFloatingWindow(_ videoView: UIView?) {
        // 清除悬浮窗视图引用
        floatingVideoView = nil
    }
    
    /// 从悬浮窗恢复后重新绑定视频
    public override func onRestoredFromFloatingWindow() {
        super.onRestoredFromFloatingWindow()
        // 重新设置远端视频渲染到原始容器
        if let uid = remoteUid {
            callManager.setupRemoteVideoView(remoteVideoContainer, forUid: uid)
        }
        // 本地小窗重新设置渲染
        callManager.setupLocalVideoView(miniVideoView)
        callManager.startPreview()
    }
    
    public override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    public override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}
