//
//  GroupVideoCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit

/// 群聊视频通话界面（支持网格布局，动态增删视频窗口）
open class GroupVideoCallViewController: BaseCallViewController {
    
    // MARK: - UI 组件
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    private let userCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        return label
    }()
    
    // 存储每个用户的视频视图
    private var videoViews: [UInt: UIView] = [:]
    private var videoConstraints: [NSLayoutConstraint] = []
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupGroupVideoUI()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateVideoLayout()
        // 重新设置本地视频渲染，确保布局完成后视频渲染器正确初始化
        if let localView = videoViews[0] {
            callManager.setupLocalVideoView(localView)
        }
    }
    
    private func setupGroupVideoUI() {
        view.insertSubview(containerView, at: 0)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        view.addSubview(userCountLabel)
        userCountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userCountLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            userCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            userCountLabel.widthAnchor.constraint(equalToConstant: 80),
            userCountLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let localView = createVideoView(for: 0, name: "我")
        videoViews[0] = localView
        callManager.setupLocalVideoView(localView)
        updateUserCountLabel()
    }
    
    private func createVideoView(for uid: UInt, name: String) -> UIView {
        let view = UIView()
        view.backgroundColor = .darkGray
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        
        let label = UILabel()
        label.text = name
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.textAlignment = .center
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        containerView.addSubview(view)
        return view
    }
    
    open override var remoteVideoView: UIView? {
        // 群聊中返回第一个远端用户的视频视图
        videoViews.first(where: { $0.key != 0 })?.value
    }
    
    private func updateUserCountLabel() {
        userCountLabel.text = "在线: \(videoViews.count)"
    }
    
    open override func didConnect(withUser user: CallUser) {
        super.didConnect(withUser: user)
        // 通话连接后设置本地视频渲染
        if let view = videoViews[0] {
            callManager.setupLocalVideoView(view)
            // 关键：启动本地视频预览
            callManager.startPreview()
        }
        updateUserCountLabel()
    }
    
    // MARK: - 用户加入/离开处理
    open override func remoteUserDidJoin(_ user: CallUser) {
        super.remoteUserDidJoin(user)
        let videoView = createVideoView(for: user.uid, name: user.name)
        videoViews[user.uid] = videoView
        callManager.setupRemoteVideoView(videoView, forUid: user.uid)
        updateUserCountLabel()
        updateVideoLayout()
    }
    
    open override func remoteUserDidLeave(_ user: CallUser) {
        super.remoteUserDidLeave(user)
        if let view = videoViews[user.uid] {
            view.removeFromSuperview()
            videoViews.removeValue(forKey: user.uid)
            callManager.engine.removeRemoteVideoView(forUid: user.uid)
        }
        updateUserCountLabel()
        updateVideoLayout()
    }
    
    // MARK: - 布局逻辑
    private func updateVideoLayout() {
        NSLayoutConstraint.deactivate(videoConstraints)
        videoConstraints.removeAll()
        
        let views = Array(videoViews.values)
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        switch views.count {
        case 0: break
        case 1: layoutOne(views)
        case 2: layoutTwo(views)
        case 3: layoutThree(views)
        case 4: layoutFour(views)
        default: layoutGrid(views)
        }
        NSLayoutConstraint.activate(videoConstraints)
    }
    
    private func layoutOne(_ views: [UIView]) {
        guard let view = views.first else { return }
        videoConstraints.append(contentsOf: [
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            view.topAnchor.constraint(equalTo: containerView.topAnchor),
            view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func layoutTwo(_ views: [UIView]) {
        videoConstraints.append(contentsOf: [
            views[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            views[0].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            views[0].topAnchor.constraint(equalTo: containerView.topAnchor),
            views[0].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            views[1].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            views[1].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            views[1].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            views[1].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5)
        ])
    }
    
    private func layoutThree(_ views: [UIView]) {
        videoConstraints.append(contentsOf: [
            views[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            views[0].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            views[0].topAnchor.constraint(equalTo: containerView.topAnchor),
            views[0].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            views[1].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            views[1].trailingAnchor.constraint(equalTo: containerView.centerXAnchor),
            views[1].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            views[1].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            views[2].leadingAnchor.constraint(equalTo: containerView.centerXAnchor),
            views[2].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            views[2].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            views[2].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5)
        ])
    }
    
    private func layoutFour(_ views: [UIView]) {
        videoConstraints.append(contentsOf: [
            views[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            views[0].trailingAnchor.constraint(equalTo: containerView.centerXAnchor),
            views[0].topAnchor.constraint(equalTo: containerView.topAnchor),
            views[0].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            views[1].leadingAnchor.constraint(equalTo: containerView.centerXAnchor),
            views[1].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            views[1].topAnchor.constraint(equalTo: containerView.topAnchor),
            views[1].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            views[2].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            views[2].trailingAnchor.constraint(equalTo: containerView.centerXAnchor),
            views[2].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            views[2].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            views[3].leadingAnchor.constraint(equalTo: containerView.centerXAnchor),
            views[3].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            views[3].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            views[3].heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5)
        ])
    }
    
    private func layoutGrid(_ views: [UIView]) {
        let columns = Int(ceil(sqrt(Double(views.count))))
        let rows = Int(ceil(Double(views.count) / Double(columns)))
        for (index, view) in views.enumerated() {
            let row = index / columns
            let col = index % columns
            videoConstraints.append(contentsOf: [
                view.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.0 / CGFloat(columns)),
                view.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 1.0 / CGFloat(rows)),
                view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: CGFloat(col) * containerView.bounds.width / CGFloat(columns)),
                view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: CGFloat(row) * containerView.bounds.height / CGFloat(rows))
            ])
        }
    }
    
    // MARK: - 悬浮窗支持（可选）
    public override var floatingWindowTitle: String {
        return "群组视频"
    }
    
    public override var floatingWindowSubtitle: String? {
        return "\(videoViews.count)人在通话"
    }
    
    public override var isVideoCall: Bool {
        return true
    }
    
    public override func getFloatingWindowVideoView() -> UIView? {
            // 返回第一个非本地的用户视图（也可按需选择主画面用户）
            return videoViews.first(where: { $0.key != 0 })?.value
        }
    
    public override func restoreFromFloatingWindow(_ videoView: UIView?) {
        // 不在此处重新绑定，在 onRestoredFromFloatingWindow 中处理
    }
    
    /// 从悬浮窗恢复后重新绑定视频
    public override func onRestoredFromFloatingWindow() {
        super.onRestoredFromFloatingWindow()
        // 重新设置所有远程视频渲染视图
        for (uid, videoView) in videoViews where uid != 0 {
            callManager.setupRemoteVideoView(videoView, forUid: uid)
        }
        // 恢复本地视频渲染
        if let localView = videoViews[0] {
            callManager.setupLocalVideoView(localView)
            callManager.startPreview()
        }
        // 触发重新布局
        updateVideoLayout()
    }
    
    public override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    public override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
    
    /// 画中画停止后恢复远程视频渲染
    /// ReadOnly 模式下 Agora 渲染管线未中断，但需要重新绑定远程视频视图
    open override func restoreVideoViewsAfterPip() {
        super.restoreVideoViewsAfterPip()
        // 重新设置所有远程视频渲染视图
        for (uid, videoView) in videoViews where uid != 0 {
            callManager.setupRemoteVideoView(videoView, forUid: uid)
        }
    }
}
