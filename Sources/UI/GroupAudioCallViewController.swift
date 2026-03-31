//
//  GroupAudioCallViewController.swift
//  CallCore
//
//  Created by Vince on 2021/4/25.
//

import UIKit
import CallCore

/// 群聊音频通话界面（显示用户列表，包含静音状态）
class GroupAudioCallViewController: BaseCallViewController {
    
    // MARK: - UI 组件
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = 70
        tv.register(GroupAudioCell.self, forCellReuseIdentifier: "GroupAudioCell")
        return tv
    }()
    
    private let userCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .white
        return label
    }()
    
    private var userList: [(uid: UInt, userId: String, isAudioMuted: Bool)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioUI()
        
        // 隐藏视频相关按钮
        muteVideoButton.isHidden = true
        switchCameraButton.isHidden = true
    }
    
    private func setupAudioUI() {
        // 用户数量标签
        view.addSubview(userCountLabel)
        userCountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userCountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            userCountLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
        
        // 表格视图
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: userCountLabel.bottomAnchor, constant: 20),
            tableView.bottomAnchor.constraint(equalTo: controlStackView.topAnchor, constant: -20)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // 添加本地用户
        updateUserList()
    }
    
    private func updateUserList() {
        userList.removeAll()
        // 添加本地用户
        if let localId = callManager.userProvider?.currentUserId {
            userList.append((0, localId, false)) // uid 0 表示本地
        }
        // 添加远端用户（实际项目中可以从 CallManager 获取远端用户列表，这里简化）
        // 由于 CallCore 当前未维护群组用户列表，你需要扩展 CallManager 来存储群组成员
        // 这里仅做示例，实际应监听 remoteUserDidJoin/Leave 来更新列表
        tableView.reloadData()
        userCountLabel.text = "在线人数: \(userList.count)"
    }
    
    override func remoteUserDidJoin(uid: UInt, userId: String) {
        super.remoteUserDidJoin(uid: uid, userId: userId)
        userList.append((uid, userId, false))
        tableView.reloadData()
        userCountLabel.text = "在线人数: \(userList.count)"
    }
    
    override func remoteUserDidLeave(uid: UInt, userId: String) {
        super.remoteUserDidLeave(uid: uid, userId: userId)
        userList.removeAll { $0.uid == uid }
        tableView.reloadData()
        userCountLabel.text = "在线人数: \(userList.count)"
    }
    
    // 可选：监听远端静音状态变化（需 CallManager 扩展）
    // 这里简单示例，实际可监听 CallUIDelegate 中新增的方法
    
    // MARK: - 悬浮窗支持（可选）
    override var floatingWindowTitle: String {
        return "群组音频"
    }
    
    override var floatingWindowSubtitle: String? {
        return "\(userList.count)人在线"
    }
    
    override var isVideoCall: Bool {
        return false
    }
    
    override func getFloatingWindowVideoView() -> UIView? {
        return nil
    }
    
    override func restoreFromFloatingWindow(_ videoView: UIView?) { }
    
    override func endCallFromFloatingWindow() {
        callManager.hangUp()
    }
    
    override func getCurrentCallDuration() -> TimeInterval {
        return callManager.getCurrentDuration()
    }
}

// MARK: - UITableView DataSource & Delegate
extension GroupAudioCallViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupAudioCell", for: indexPath) as! GroupAudioCell
        let user = userList[indexPath.row]
        let isLocal = user.uid == 0
        cell.configure(name: user.userId + (isLocal ? " (我)" : ""), isMuted: user.isAudioMuted)
        return cell
    }
}

// MARK: - 自定义 Cell
class GroupAudioCell: UITableViewCell {
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let micIcon = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 25
        avatarView.clipsToBounds = true
        avatarView.backgroundColor = .systemGray5
        avatarView.image = UIImage(systemName: "person.circle.fill")
        avatarView.tintColor = .systemGray2
        
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = .white
        
        micIcon.contentMode = .scaleAspectFit
        micIcon.tintColor = .white
        
        let stack = UIStackView(arrangedSubviews: [avatarView, nameLabel, micIcon])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            avatarView.widthAnchor.constraint(equalToConstant: 50),
            avatarView.heightAnchor.constraint(equalToConstant: 50),
            micIcon.widthAnchor.constraint(equalToConstant: 24),
            micIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(name: String, isMuted: Bool) {
        nameLabel.text = name
        micIcon.image = UIImage(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
        micIcon.tintColor = isMuted ? .systemRed : .systemGreen
    }
}
