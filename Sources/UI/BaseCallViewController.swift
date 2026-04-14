//
//  BaseCallViewController.swift
//  AgoraCallCore
//
//  Created by Vince on 2021/3/29.
//

import UIKit

/// 通话界面基类，提供通用 UI 布局和状态管理
open class BaseCallViewController: UIViewController, CallUIDelegate, FloatingWindowCompatible {
    
    // MARK: - 公共属性
    public let callManager = CallManager.shared
    public var callType: CallType? { callManager.getCurrentCallType }
    public var remoteUser: CallUser? { callManager.getCurrentRemoteUser }
    
    // MARK: - 按钮尺寸常量
    /// 所有按钮圆形背景直径（统一 65pt）
    public let buttonSize: CGFloat = 65
    /// 按钮图标大小
    public let buttonIconSize: CGFloat = 28
    
    // MARK: - UI 组件
    
    /// 顶部容器
    public let topBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    /// 缩小按钮（悬浮窗入口）
    public let minimizeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.isHidden = true
        return btn
    }()
    
    /// 通话时长标签
    public let durationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.isHidden = true
        return label
    }()
    
    /// 状态标签
    public let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white.withAlphaComponent(0.8)
        return label
    }()
    
    // MARK: - 底部按钮（微信风格：圆形背景图 + 图标 + 底部文字）
    
    public lazy var muteAudioButton: UIButton = createActionButton(
        imageName: "mic.fill", title: "麦克风",
        bgColor: .white.withAlphaComponent(0.2),
        selectedBgColor: .white,
        tintColor: .white,
        selectedTintColor: .darkGray
    )
    
    public lazy var muteVideoButton: UIButton = createActionButton(
        imageName: "video.fill", title: "摄像头",
        bgColor: .white.withAlphaComponent(0.2),
        selectedBgColor: .white,
        tintColor: .white,
        selectedTintColor: .darkGray
    )
    
    public lazy var speakerButton: UIButton = createActionButton(
        imageName: "speaker.wave.2.fill", title: "扬声器",
        bgColor: .white.withAlphaComponent(0.2),
        selectedBgColor: .white,
        tintColor: .white,
        selectedTintColor: .darkGray
    )
    
    public lazy var switchCameraButton: UIButton = createActionButton(
        imageName: "camera.rotate.fill", title: "翻转",
        bgColor: .white.withAlphaComponent(0.2),
        tintColor: .white
    )
    
    public lazy var endCallButton: UIButton = createCallButton(
        imageName: "phone.down.fill", title: "挂断",
        bgColor: UIColor(hex: "F55C5C")
    )
    
    public lazy var acceptCallButton: UIButton = createCallButton(
        imageName: "phone.fill", title: "接听",
        bgColor: UIColor(hex: "4CD964")
    )
    
    public lazy var rejectCallButton: UIButton = createCallButton(
        imageName: "phone.down.fill", title: "挂断",
        bgColor: UIColor(hex: "F55C5C")
    )
    
    // 底部按钮容器
    public let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.distribution = .equalSpacing
        return stack
    }()
    
    public let controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        return stack
    }()
    
    public let callStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        return stack
    }()
    
    // 画中画相关
    private var isPictureInPictureActive = false
    private var isNotificationsRegistered = false
    
    // MARK: - UIImage 圆形图片扩展
    
    /// 生成圆形纯色背景 + 居中 SF Symbol 图标的图片
    /// - Parameters:
    ///   - size: 圆形直径
    ///   - bgColor: 圆形背景色
    ///   - iconName: SF Symbol 名称
    ///   - iconSize: 图标尺寸
    ///   - iconColor: 图标颜色
    /// - Returns: 带圆形背景的图片
    private func circleImage(size: CGFloat, bgColor: UIColor, iconName: String, iconSize: CGFloat, iconColor: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            // 画圆形背景
            bgColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
            // 画居中图标
            let icon = UIImage(systemName: iconName)!
            let iconRect = CGRect(
                x: (size - iconSize) / 2,
                y: (size - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            let tinted = icon.withTintColor(iconColor, renderingMode: .alwaysOriginal)
            tinted.draw(in: iconRect)
        }
    }
    
    // MARK: - 创建微信风格按钮
    
    /// 创建功能按钮（麦克风/扬声器/摄像头/翻转）
    /// 圆形半透明背景 + 白色图标 + 底部文字，选中时背景变白+图标变深色
    private func createActionButton(
        imageName: String,
        title: String,
        bgColor: UIColor = .white.withAlphaComponent(0.2),
        selectedBgColor: UIColor = .white,
        tintColor: UIColor = .white,
        selectedTintColor: UIColor = .darkGray
    ) -> UIButton {
        let normalImage = circleImage(
            size: buttonSize,
            bgColor: bgColor,
            iconName: imageName,
            iconSize: buttonIconSize,
            iconColor: tintColor
        )
        let selectedImage = circleImage(
            size: buttonSize,
            bgColor: selectedBgColor,
            iconName: imageName,
            iconSize: buttonIconSize,
            iconColor: selectedTintColor
        )
        
        let btn = UIButton(type: .custom)
        btn.setImage(normalImage, for: .normal)
        btn.setImage(selectedImage, for: .selected)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(tintColor.withAlphaComponent(0.8), for: .normal)
        btn.setTitleColor(selectedTintColor.withAlphaComponent(0.8), for: .selected)
        btn.titleLabel?.font = .systemFont(ofSize: 11)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        // 图标在上，文字在下
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = normalImage
            config.title = title
            config.imagePlacement = .top
            config.imagePadding = 6
            config.baseBackgroundColor = .clear
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            btn.configuration = config
            // 选中状态通过 updateConfiguration 手动处理
            btn.configurationUpdateHandler = { button in
                var updatedConfig = button.configuration
                let isSelected = button.isSelected
                updatedConfig?.image = isSelected ? selectedImage : normalImage
                updatedConfig?.title = button.titleLabel?.text
                let color = isSelected ? selectedTintColor.withAlphaComponent(0.8) : tintColor.withAlphaComponent(0.8)
                updatedConfig?.baseForegroundColor = color
                button.configuration = updatedConfig
            }
        } else {
            btn.setImage(normalImage, for: .normal)
            btn.setImage(selectedImage, for: .selected)
            btn.setTitle(title, for: .normal)
            btn.titleEdgeInsets = UIEdgeInsets(top: buttonSize + 6, left: -buttonSize, bottom: 0, right: 0)
            btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -title.size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width)
        }
        
        return btn
    }
    
    /// 创建挂断/接听按钮（纯色大圆 + 白色图标 + 底部文字）
    private func createCallButton(
        imageName: String,
        title: String,
        bgColor: UIColor
    ) -> UIButton {
        let normalImage = circleImage(
            size: buttonSize,
            bgColor: bgColor,
            iconName: imageName,
            iconSize: buttonIconSize,
            iconColor: .white
        )
        
        let btn = UIButton(type: .custom)
        btn.setImage(normalImage, for: .normal)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white.withAlphaComponent(0.9), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = normalImage
            config.title = title
            config.imagePlacement = .top
            config.imagePadding = 6
            config.baseForegroundColor = .white.withAlphaComponent(0.9)
            config.baseBackgroundColor = .clear
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            btn.configuration = config
            btn.configurationUpdateHandler = { button in
                var updatedConfig = button.configuration
                updatedConfig?.title = button.titleLabel?.text
                button.configuration = updatedConfig
            }
        } else {
            btn.titleEdgeInsets = UIEdgeInsets(top: buttonSize + 6, left: -buttonSize, bottom: 0, right: 0)
            btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -title.size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)]).width)
        }
        
        return btn
    }
    
    // MARK: - 生命周期
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupBaseUI()
        setupActions()
        updateUIForState(callManager.currentState)
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 注册为多播 delegate，接收 UI 回调
        callManager.uiDelegate.add(self)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 移除多播 delegate，不再接收回调
        callManager.uiDelegate.remove(self)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        registerNotifications()
    }
    
    // MARK: - UI 布局
    open func setupBaseUI() {
        // 顶部栏
        view.addSubview(topBarView)
        topBarView.addSubview(minimizeButton)
        topBarView.addSubview(durationLabel)
        
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 60),
            
            minimizeButton.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: 16),
            minimizeButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            minimizeButton.widthAnchor.constraint(equalToConstant: 40),
            minimizeButton.heightAnchor.constraint(equalToConstant: 40),
            
            durationLabel.centerXAnchor.constraint(equalTo: topBarView.centerXAnchor),
            durationLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            durationLabel.heightAnchor.constraint(equalToConstant: 30),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
        
        // 状态标签
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: topBarView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        // 底部控制按钮
        controlStackView.addArrangedSubview(muteAudioButton)
        controlStackView.addArrangedSubview(speakerButton)
        controlStackView.addArrangedSubview(muteVideoButton)
        controlStackView.addArrangedSubview(endCallButton)
        
        callStackView.addArrangedSubview(rejectCallButton)
        callStackView.addArrangedSubview(acceptCallButton)
        callStackView.addArrangedSubview(switchCameraButton)
        
        view.addSubview(actionStackView)
        actionStackView.addArrangedSubview(controlStackView)
        actionStackView.addArrangedSubview(callStackView)
        
        actionStackView.translatesAutoresizingMaskIntoConstraints = false
        controlStackView.translatesAutoresizingMaskIntoConstraints = false
        callStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            actionStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            actionStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            actionStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            controlStackView.heightAnchor.constraint(equalToConstant: 95),
            callStackView.heightAnchor.constraint(equalToConstant: 95),
        ])
        
        // 初始隐藏所有按钮
        muteAudioButton.isHidden = true
        speakerButton.isHidden = true
        muteVideoButton.isHidden = true
        endCallButton.isHidden = true
        rejectCallButton.isHidden = true
        acceptCallButton.isHidden = true
        switchCameraButton.isHidden = true
        
        // 缩小按钮点击
        minimizeButton.addTarget(self, action: #selector(minimizeTapped), for: .touchUpInside)
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
    
    @objc private func minimizeTapped() {
        FloatingWindowManager.shared.showFloatingWindow(from: self)
        dismiss(animated: true)
    }
    
    /// 从悬浮窗恢复后重新绑定视频（子类重写）
    open func onRestoredFromFloatingWindow() { }
    
    // MARK: - 通知注册（画中画、前后台）
    private func registerNotifications() {
        guard !isNotificationsRegistered else { return }
        isNotificationsRegistered = true
        if callType == .video {
            NotificationCenter.default.addObserver(self, selector: #selector(pipWillStart), name: .pipWillStart, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(pipDidStop), name: .pipDidStop, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func initPictureInPicture() {
        guard callType == .video else { return }
        let videoSize = remoteVideoView?.bounds.size ?? localVideoView?.bounds.size ?? CGSize(width: 360, height: 640)
        PictureInPictureManager.shared.setup(initialSize: videoSize)
        callManager.engine.startPiPCapturer(remoteVideoView: remoteVideoView)
    }
    
    @objc private func applicationDidEnterBackground() {
        guard callType == .video, !isPictureInPictureActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            PictureInPictureManager.shared.start()
        }
    }
    
    @objc private func applicationWillEnterForeground() {
        if isPictureInPictureActive {
            PictureInPictureManager.shared.stop()
        }
    }
    
    @objc private func pipWillStart() {
        isPictureInPictureActive = true
        localVideoView?.isHidden = true
    }
    
    @objc private func pipDidStop() {
        isPictureInPictureActive = false
        localVideoView?.isHidden = false
        restoreVideoViewsAfterPip()
    }
    
    /// 本地视频视图（子类重写）
    open var localVideoView: UIView? { nil }
    /// 远端视频视图（子类重写）
    open var remoteVideoView: UIView? { nil }
    /// 画中画停止后恢复视频渲染（子类重写）
    open func restoreVideoViewsAfterPip() { }
    
    // MARK: - 控制方法
    
    @objc open func toggleAudio() {
        CallSoundService.shared.playButtonClickSound()
        let newState = !muteAudioButton.isSelected
        callManager.muteAudio(newState)
        muteAudioButton.isSelected = newState
        updateToggleButton(muteAudioButton, isMuted: newState,
                           onImage: "mic.fill", offImage: "mic.slash.fill",
                           onTitle: "麦克风", offTitle: "已静音")
    }
    
    @objc open func toggleVideo() {
        CallSoundService.shared.playButtonClickSound()
        let newState = !muteVideoButton.isSelected
        callManager.muteVideo(newState)
        muteVideoButton.isSelected = newState
        updateToggleButton(muteVideoButton, isMuted: newState,
                           onImage: "video.fill", offImage: "video.slash.fill",
                           onTitle: "摄像头", offTitle: "已关闭")
    }
    
    @objc open func toggleSpeaker() {
        CallSoundService.shared.playButtonClickSound()
        let newState = !speakerButton.isSelected
        callManager.setSpeakerEnabled(newState)
        speakerButton.isSelected = newState
        updateToggleButton(speakerButton, isMuted: newState,
                           onImage: "speaker.wave.2.fill", offImage: "speaker.fill",
                           onTitle: "扬声器", offTitle: "免提")
    }
    
    /// 更新功能按钮的图标和文字（选中时自动切换圆形背景图）
    private func updateToggleButton(_ button: UIButton, isMuted: Bool, onImage: String, offImage: String, onTitle: String, offTitle: String) {
        let iconName = isMuted ? offImage : onImage
        let title = isMuted ? offTitle : onTitle
        
        if #available(iOS 15.0, *) {
            // configurationUpdateHandler 会自动根据 isSelected 切换图片和颜色
            // 只需更新 icon 名称和 title，重新生成图片
            let tintColor: UIColor = isMuted ? .darkGray : .white
            let bgColor: UIColor = isMuted ? .white : .white.withAlphaComponent(0.2)
            let newSize = buttonSize
            let newIconSize = buttonIconSize
            
            let newImage = circleImage(
                size: newSize,
                bgColor: bgColor,
                iconName: iconName,
                iconSize: newIconSize,
                iconColor: tintColor
            )
            if var config = button.configuration {
                config.image = newImage
                config.title = title
                config.baseForegroundColor = tintColor.withAlphaComponent(0.8)
                button.configuration = config
            }
        } else {
            let tintColor: UIColor = isMuted ? .darkGray : .white
            let bgColor: UIColor = isMuted ? .white : .white.withAlphaComponent(0.2)
            let newImage = circleImage(
                size: buttonSize,
                bgColor: bgColor,
                iconName: iconName,
                iconSize: buttonIconSize,
                iconColor: tintColor
            )
            button.setImage(newImage, for: .normal)
            button.setTitle(title, for: .normal)
            button.setTitleColor(tintColor.withAlphaComponent(0.8), for: .normal)
        }
    }
    
    /// 更新挂断/接听按钮的文字
    private func updateButtonTitle(_ button: UIButton, title: String) {
        if #available(iOS 15.0, *) {
            if var config = button.configuration {
                config.title = title
                button.configuration = config
            }
        } else {
            button.setTitle(title, for: .normal)
        }
    }
    
    @objc open func switchCamera() {
        CallSoundService.shared.playButtonClickSound()
        callManager.switchCamera()
    }
    
    @objc open func endCall() {
        CallSoundService.shared.playButtonClickSound()
        callManager.hangUp()
        dismiss(animated: true)
    }
    
    @objc open func acceptCall() {
        CallSoundService.shared.playButtonClickSound()
        callManager.acceptCall()
    }
    
    @objc open func rejectCall() {
        CallSoundService.shared.playButtonClickSound()
        if callManager.currentState == .incoming {
            callManager.rejectCall()
        } else {
            callManager.hangUp()
        }
        dismiss(animated: true)
    }
    
    open func showControlButtons(_ show: Bool) {
        controlStackView.isHidden = !show
    }
    
    // MARK: - 状态更新
    open func updateUIForState(_ state: CallState) {
        switch state {
        case .calling:
            statusLabel.text = "呼叫中..."
            durationLabel.isHidden = true
            updateButtonsForState(state)
        case .incoming:
            statusLabel.text = "来电..."
            durationLabel.isHidden = true
            updateButtonsForState(state)
        case .connecting:
            statusLabel.text = "连接中..."
            durationLabel.isHidden = true
            updateButtonsForState(state)
        case .connected:
            statusLabel.text = "通话中"
            durationLabel.isHidden = false
            updateButtonsForState(state)
        case .reconnecting:
            statusLabel.text = "重连中..."
            durationLabel.isHidden = false
        case .disconnected, .failed:
            statusLabel.text = state == .disconnected ? "通话结束" : "通话失败"
            durationLabel.isHidden = true
            // 显示关闭按钮，让用户可以退出
            controlStackView.isHidden = true
            callStackView.isHidden = false
            rejectCallButton.isHidden = true
            acceptCallButton.isHidden = true
            switchCameraButton.isHidden = true
            muteAudioButton.isHidden = true
            speakerButton.isHidden = true
            muteVideoButton.isHidden = true
            endCallButton.isHidden = false
            updateButtonTitle(endCallButton, title: "关闭")
        default:
            break
        }
        minimizeButton.isHidden = (state != .connected)
    }
    
    /// 根据通话类型、状态和角色更新按钮布局
    private func updateButtonsForState(_ state: CallState) {
        let isVideo = callType == .video
        
        if state == .incoming {
            // 来电时：隐藏控制按钮，只显示接听/拒绝
            muteAudioButton.isHidden = true
            speakerButton.isHidden = true
            muteVideoButton.isHidden = true
            endCallButton.isHidden = true
            switchCameraButton.isHidden = true
            
            rejectCallButton.isHidden = false
            updateButtonTitle(rejectCallButton, title: "拒绝")
            acceptCallButton.isHidden = false
            updateButtonTitle(acceptCallButton, title: "接听")
            
            controlStackView.isHidden = true
            callStackView.isHidden = false
        } else if state == .calling {
            if isVideo {
                muteAudioButton.isHidden = false
                speakerButton.isHidden = false
                muteVideoButton.isHidden = false
                endCallButton.isHidden = true
                switchCameraButton.isHidden = false
                
                rejectCallButton.isHidden = false
                updateButtonTitle(rejectCallButton, title: "取消")
                acceptCallButton.isHidden = true
                
                controlStackView.isHidden = false
                callStackView.isHidden = false
            } else {
                // 语音呼叫：静音 + 扬声器 + 取消按钮，同一行
                muteAudioButton.isHidden = false
                speakerButton.isHidden = false
                muteVideoButton.isHidden = true
                endCallButton.isHidden = false
                updateButtonTitle(endCallButton, title: "取消")
                switchCameraButton.isHidden = true
                
                rejectCallButton.isHidden = true
                acceptCallButton.isHidden = true
                
                controlStackView.isHidden = false
                callStackView.isHidden = true
            }
        } else if state == .connected {
            if isVideo {
                muteAudioButton.isHidden = false
                speakerButton.isHidden = false
                muteVideoButton.isHidden = false
                endCallButton.isHidden = true
                switchCameraButton.isHidden = false
                
                rejectCallButton.isHidden = false
                updateButtonTitle(rejectCallButton, title: "挂断")
                acceptCallButton.isHidden = true
                
                controlStackView.isHidden = false
                callStackView.isHidden = false
            } else {
                // 语音通话：静音 + 扬声器 + 挂断按钮，同一行
                muteAudioButton.isHidden = false
                speakerButton.isHidden = false
                muteVideoButton.isHidden = true
                endCallButton.isHidden = false
                updateButtonTitle(endCallButton, title: "挂断")
                switchCameraButton.isHidden = true
                
                rejectCallButton.isHidden = true
                acceptCallButton.isHidden = true
                
                controlStackView.isHidden = false
                callStackView.isHidden = true
            }
        } else if state == .connecting {
            if isVideo {
                muteAudioButton.isHidden = false
                speakerButton.isHidden = false
                muteVideoButton.isHidden = false
                endCallButton.isHidden = true
                switchCameraButton.isHidden = false
                
                rejectCallButton.isHidden = false
                updateButtonTitle(rejectCallButton, title: "取消")
                acceptCallButton.isHidden = true
                
                controlStackView.isHidden = false
                callStackView.isHidden = false
            } else {
                // 语音连接中：静音 + 扬声器 + 取消按钮，同一行
                muteAudioButton.isHidden = false
                speakerButton.isHidden = false
                muteVideoButton.isHidden = true
                endCallButton.isHidden = false
                updateButtonTitle(endCallButton, title: "取消")
                switchCameraButton.isHidden = true
                
                rejectCallButton.isHidden = true
                acceptCallButton.isHidden = true
                
                controlStackView.isHidden = false
                callStackView.isHidden = true
            }
        } else {
            controlStackView.isHidden = true
            callStackView.isHidden = true
        }
    }
    
    open func updateDuration(_ duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - CallUIDelegate
    public func callStateDidChange(_ state: CallState) {
        updateUIForState(state)
    }
    
    open func didJoinChannel(withUser user: CallUser) {
        if callType == .video { initPictureInPicture() }
    }
    
    open func didDisconnect(error: Error?) {
        IncomingCallManager.shared.hide()
        if presentingViewController != nil {
            statusLabel.text = error == nil ? "通话结束" : "通话失败"
            // 统一延迟 dismiss，让用户能看到通话结束/失败的状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.dismiss(animated: true)
            }
        }
    }
    
    open func remoteUserDidJoin(_ user: CallUser) { }
    open func remoteUserDidLeave(_ user: CallUser) { }
    
    open func remoteUserDidToggleVideo(_ user: CallUser, muted: Bool) { }
    open func remoteUserDidToggleAudio(_ user: CallUser, muted: Bool) { }
    
    open func localAudioMutedDidChange(_ muted: Bool) { }
    open func localVideoMutedDidChange(_ muted: Bool) { }
    
    public func didUpdateDuration(_ duration: TimeInterval) {
        DispatchQueue.main.async { self.updateDuration(duration) }
    }
    
    public func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {
        updateUIForState(.incoming)
    }
    
    public func didOccurError(_ error: Error) {
        // 不直接 dismiss，由 didDisconnect 统一处理 dismiss 逻辑
        // （发起通话阶段 Token/信令失败也会触发此回调，直接 dismiss 会导致刚 present 就被关闭）
    }
    
    // MARK: - FloatingWindowCompatible 默认实现
    public var floatingWindowTitle: String { remoteUser?.name ?? "通话中" }
    public var floatingWindowSubtitle: String? { nil }
    public var isVideoCall: Bool { callType == .video }
    open func getFloatingWindowVideoView() -> UIView? { nil }
    open func bindRemoteVideoToFloatingView(_ view: UIView) { }
    open func restoreFromFloatingWindow(_ videoView: UIView?) { }
    open func endCallFromFloatingWindow() { callManager.hangUp() }
    open func getCurrentCallDuration() -> TimeInterval { callManager.getCurrentDuration() }
}

// MARK: - UIColor Hex 便捷扩展
private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
