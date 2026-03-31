//
//  GroupVideoCallViewController.swift
//  CallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit
import CallCore

/// 群聊视频通话界面（支持网格布局，动态增删视频窗口）
class GroupVideoCallViewController: BaseCallViewController {
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGroupVideoUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateVideoLayout()
    }
    
    private func setupGroupVideoUI() {
        // 容器视图（用于放置所有视频窗口）
        view.insertSubview(containerView, at: 0)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 用户数量标签
        view.addSubview(userCountLabel)
        userCountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userCountLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            userCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            userCountLabel.widthAnchor.constraint(equalToConstant: 80),
            userCountLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // 群聊视频通话默认显示控制按钮
        showControlButtons(true)
        
        // 设置本地视频视图
        let localView = createVideoView(for: 0, isLocal: true)
        videoViews[0] = localView
        callManager.setupLocalVideoView(localView)
        updateUserCountLabel()
    }
    
    private func createVideoView(for uid: UInt, isLocal: Bool) -> UIView {
        let view = UIView()
        view.backgroundColor = .darkGray
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        
        // 添加用户标识
        let label = UILabel()
        label.text = isLocal ? "我" : "用户 \(uid)"
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
    
    private func updateUserCountLabel() {
        let count = videoViews.count
        userCountLabel.text = "在线: \(count)"
    }
    
    // MARK: - 用户加入/离开处理
    override func remoteUserDidJoin(uid: UInt, userId: String) {
        super.remoteUserDidJoin(uid: uid, userId: userId)
        let videoView = createVideoView(for: uid, isLocal: false)
        videoViews[uid] = videoView
        callManager.setupRemoteVideoView(videoView, forUid: uid)
        updateUserCountLabel()
        updateVideoLayout()
    }
    
    override func remoteUserDidLeave(uid: UInt, userId: String) {
        super.remoteUserDidLeave(uid: uid, userId: userId)
        if let view = videoViews[uid] {
            view.removeFromSuperview()
            videoViews.removeValue(forKey: uid)
            callManager.engine.removeRemoteVideoView(forUid: uid)
        }
        updateUserCountLabel()
        updateVideoLayout()
    }
    
    // MARK: - 布局逻辑
    private func updateVideoLayout() {
        // 移除所有约束
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
        guard views.count == 2 else { return }
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
        guard views.count == 3 else { return }
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
        guard views.count == 4 else { return }
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
    override var floatingWindowTitle: String {
        return "群组视频"
    }
    
    override var floatingWindowSubtitle: String? {
        return "\(videoViews.count)人在通话"
    }
    
    override var isVideoCall: Bool {
        return true
    }
    
    override func getFloatingWindowVideoView() -> UIView? {
        // 返回本地视频视图
        return videoViews[0]
    }
    
    override func restoreFromFloatingWindow(_ videoView: UIView?) {
        if let videoView = videoView, let localView = videoViews[0] {
            videoView.frame = localView.bounds
            videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            localView.addSubview(videoView)
        }
    }
    
    override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}
