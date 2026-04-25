//
//  ViewController.swift
//  Example
//
//  通话功能示例界面
//

import UIKit
import AgoraCallKit

class ViewController: UIViewController {
    
    // MARK: - UI 组件
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AgoraCallKit 示例"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var configStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - 生命周期
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateConfigStatus()
    }
    
    // MARK: - UI 布局
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        // 标题
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(configStatusLabel)
        stackView.setCustomSpacing(8, after: titleLabel)
        stackView.setCustomSpacing(32, after: configStatusLabel)
        
        // 配置模式选择
        addSection(title: "系统来电界面配置")
        addButton(title: "App 内弹窗模式", action: #selector(configAppOnly))
        addButton(title: "CallKit 模式", action: #selector(configCallKitOnly))
        addButton(title: "LiveCommunicationKit 模式", action: #selector(configLiveCommunicationKit))
        addButton(title: "VoIP 推送触发模式", action: #selector(configVoipPushOnly))
        
        // 通话操作
        addSection(title: "通话操作")
        addButton(title: "发起视频通话", action: #selector(startVideoCall))
        addButton(title: "发起音频通话", action: #selector(startAudioCall))
        addButton(title: "模拟来电（App 内弹窗）", action: #selector(simulateIncomingCall))
        addButton(title: "模拟来电（系统界面）", action: #selector(simulateIncomingCallWithSystem))
        
        // 状态查询
        addSection(title: "状态查询")
        addButton(title: "查看当前配置", action: #selector(printConfiguration))
        addButton(title: "查看通话状态", action: #selector(printCallState))
    }
    
    private func addSection(title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        stackView.addArrangedSubview(label)
        stackView.setCustomSpacing(8, after: label)
    }
    
    private func addButton(title: String, action: Selector) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        stackView.addArrangedSubview(button)
    }
    
    private func updateConfigStatus() {
        let framework = CallConfigurationExamples.checkCurrentFramework()
        configStatusLabel.text = "当前框架: \(framework)"
    }
    
    // MARK: - 配置操作
    
    @objc private func configAppOnly() {
        CallConfigurationExamples.configure(mode: .appOnly)
        updateConfigStatus()
        showAlert(title: "配置成功", message: "已切换到 App 内弹窗模式")
    }
    
    @objc private func configCallKitOnly() {
        CallConfigurationExamples.configure(mode: .callKitOnly)
        updateConfigStatus()
        showAlert(title: "配置成功", message: "已切换到 CallKit 模式")
    }
    
    @objc private func configLiveCommunicationKit() {
        CallConfigurationExamples.configure(mode: .liveCommunicationKit)
        updateConfigStatus()
        showAlert(title: "配置成功", message: "已切换到 LiveCommunicationKit 模式")
    }
    
    @objc private func configVoipPushOnly() {
        CallConfigurationExamples.configure(mode: .voipPushOnly)
        updateConfigStatus()
        showAlert(title: "配置成功", message: "已切换到 VoIP 推送触发模式")
    }
    
    // MARK: - 通话操作
    
    @objc private func startVideoCall() {
        // 示例：给用户 "test_user" 发起视频通话
        let targetUserId = "test_user"
        let targetUserName = "测试用户"
        
        ExampleCallServiceManager.shared.startVideoCall(
            to: targetUserId,
            userName: targetUserName,
            from: self
        )
    }
    
    @objc private func startAudioCall() {
        // 示例：给用户 "test_user" 发起音频通话
        let targetUserId = "test_user"
        let targetUserName = "测试用户"
        
        ExampleCallServiceManager.shared.startAudioCall(
            to: targetUserId,
            userName: targetUserName,
            from: self
        )
    }
    
    @objc private func simulateIncomingCall() {
        // 模拟来电（使用 App 内弹窗）
        CallConfiguration.shared.configure(mode: .none)
        
        let user = CallUser(userId: "simulator", uid: 999, name: "模拟来电")
        WebSocketSignalExamples.handleIncomingCall(
            from: user,
            channelName: "simulator_channel",
            token: "simulator_token",
            callType: .video
        )
    }
    
    @objc private func simulateIncomingCallWithSystem() {
        // 模拟来电（使用系统来电界面）
        CallConfiguration.shared.configure(mode: .auto)
        
        let user = CallUser(userId: "simulator", uid: 999, name: "模拟来电")
        WebSocketSignalExamples.handleIncomingCallFromVoIP(
            from: user,
            channelName: "simulator_channel",
            token: "simulator_token",
            callType: .video
        )
    }
    
    // MARK: - 状态查询
    
    @objc private func printConfiguration() {
        CallConfigurationExamples.printCurrentConfiguration()
    }
    
    @objc private func printCallState() {
        let state = CallManager.shared.currentState
        let isInCall = CallManager.shared.isInCall
        print("当前通话状态: \(state), 是否在通话中: \(isInCall)")
        showAlert(title: "通话状态", message: "状态: \(state)\n通话中: \(isInCall)")
    }
    
    // MARK: - 辅助方法
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
