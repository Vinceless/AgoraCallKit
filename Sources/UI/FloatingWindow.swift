//
//  FloatingWindow.swift
//  CallCore
//
//  Created by Vince on 2021/3/29.
//

import UIKit

/// 悬浮窗兼容协议，通话页面可实现该协议以支持悬浮窗
public protocol FloatingWindowCompatible: UIViewController {
    var floatingWindowTitle: String { get }
    var floatingWindowSubtitle: String? { get }
    var isVideoCall: Bool { get }
    func getFloatingWindowVideoView() -> UIView?
    func restoreFromFloatingWindow(_ videoView: UIView?)
    func endCallFromFloatingWindow()
    func getCurrentCallDuration() -> TimeInterval
}

public extension FloatingWindowCompatible {
    var floatingWindowSubtitle: String? { return nil }
    func floatingWindowWillAppear() {}
    func floatingWindowDidDisappear() {}
    func floatingWindowDidTap() {}
}

/// 悬浮窗管理器
public class FloatingWindowManager {
    public static let shared = FloatingWindowManager()
    
    private var floatingWindow: FloatingCallWindow?
    private weak var currentViewController: FloatingWindowCompatible?
    
    public func showFloatingWindow(from viewController: FloatingWindowCompatible) {
        if let existing = floatingWindow {
            existing.hide()
        }
        currentViewController = viewController
        floatingWindow = FloatingCallWindow()
        floatingWindow?.configure(with: viewController)
        floatingWindow?.show()
        viewController.floatingWindowWillAppear()
    }
    
    public func hideFloatingWindow() {
        currentViewController?.floatingWindowDidDisappear()
        floatingWindow?.hide()
        floatingWindow = nil
        currentViewController = nil
    }
    
    public func restoreFromFloatingWindow() -> FloatingWindowCompatible? {
        guard let window = floatingWindow, let vc = currentViewController else { return nil }
        let restored = window.restoreToFullscreen()
        hideFloatingWindow()
        return restored
    }
    
    public func isShowing() -> Bool {
        return floatingWindow != nil
    }
}

/// 悬浮窗视图控制器
class FloatingCallWindow: UIViewController {
    private var containerView: UIView!
    private var contentView: UIView!
    private var videoView: UIView!
    private var audioView: UIView!
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var durationLabel: UILabel!
    private var typeIcon: UIImageView!
    private var minimizeButton: UIButton!
    private var closeButton: UIButton!
    
    private weak var originalViewController: FloatingWindowCompatible?
    private var panGesture: UIPanGestureRecognizer?
    private var durationTimer: Timer?
    private var isVideoMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        startDurationTimer()
    }
    
    deinit {
        durationTimer?.invalidate()
    }
    
    func configure(with viewController: FloatingWindowCompatible) {
        originalViewController = viewController
        isVideoMode = viewController.isVideoCall
        titleLabel.text = viewController.floatingWindowTitle
        subtitleLabel.text = viewController.floatingWindowSubtitle
        typeIcon.image = UIImage(systemName: viewController.isVideoCall ? "video.fill" : "phone.fill")
        typeIcon.tintColor = .white
        if viewController.isVideoCall, let videoViewContent = viewController.getFloatingWindowVideoView() {
            setupVideoContent(videoViewContent)
            audioView.isHidden = true
            videoView.isHidden = false
        } else {
            setupAudioContent()
            videoView.isHidden = true
            audioView.isHidden = false
        }
        updateDuration()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        containerView = UIView()
        containerView.backgroundColor = .black
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowOffset = .zero
        containerView.layer.shadowRadius = 6
        view.addSubview(containerView)
        
        contentView = UIView()
        contentView.backgroundColor = .clear
        containerView.addSubview(contentView)
        
        videoView = UIView()
        videoView.backgroundColor = .black
        videoView.layer.cornerRadius = 8
        videoView.clipsToBounds = true
        contentView.addSubview(videoView)
        
        audioView = UIView()
        audioView.backgroundColor = UIColor.darkGray
        audioView.layer.cornerRadius = 8
        audioView.clipsToBounds = true
        contentView.addSubview(audioView)
        
        titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.textColor = .lightGray
        subtitleLabel.textAlignment = .center
        containerView.addSubview(subtitleLabel)
        
        durationLabel = UILabel()
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        durationLabel.textColor = .white
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        durationLabel.textAlignment = .center
        durationLabel.layer.cornerRadius = 4
        durationLabel.clipsToBounds = true
        containerView.addSubview(durationLabel)
        
        typeIcon = UIImageView()
        typeIcon.contentMode = .scaleAspectFit
        typeIcon.backgroundColor = UIColor.systemBlue
        typeIcon.layer.cornerRadius = 10
        typeIcon.clipsToBounds = true
        containerView.addSubview(typeIcon)
        
        minimizeButton = UIButton(type: .system)
        minimizeButton.setImage(UIImage(systemName: "arrow.up.right.and.arrow.down.left"), for: .normal)
        minimizeButton.tintColor = .white
        minimizeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        minimizeButton.layer.cornerRadius = 12
        minimizeButton.addTarget(self, action: #selector(restoreToFullscreenView), for: .touchUpInside)
        containerView.addSubview(minimizeButton)
        
        closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = .systemRed
        closeButton.layer.cornerRadius = 12
        closeButton.addTarget(self, action: #selector(closeCall), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        // 布局
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        videoView.translatesAutoresizingMaskIntoConstraints = false
        audioView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        typeIcon.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: 150),
            containerView.heightAnchor.constraint(equalToConstant: 180),
            
            contentView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            contentView.heightAnchor.constraint(equalToConstant: 100),
            
            videoView.topAnchor.constraint(equalTo: contentView.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            audioView.topAnchor.constraint(equalTo: contentView.topAnchor),
            audioView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            audioView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            audioView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            durationLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            durationLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 50),
            durationLabel.heightAnchor.constraint(equalToConstant: 16),
            
            typeIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -8),
            typeIcon.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 8),
            typeIcon.widthAnchor.constraint(equalToConstant: 20),
            typeIcon.heightAnchor.constraint(equalToConstant: 20),
            
            minimizeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -8),
            minimizeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 8),
            minimizeButton.widthAnchor.constraint(equalToConstant: 24),
            minimizeButton.heightAnchor.constraint(equalToConstant: 24),
            
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -8),
            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        typeIcon.isHidden = true // 隐藏默认图标，使用按钮替代
    }
    
    private func setupVideoContent(_ video: UIView) {
        videoView.subviews.forEach { $0.removeFromSuperview() }
        video.frame = videoView.bounds
        video.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.addSubview(video)
    }
    
    private func setupAudioContent() {
        audioView.subviews.forEach { $0.removeFromSuperview() }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        let avatar = UIImageView(image: UIImage(systemName: "person.circle.fill"))
        avatar.tintColor = .white
        avatar.contentMode = .scaleAspectFit
        avatar.widthAnchor.constraint(equalToConstant: 40).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stack.addArrangedSubview(avatar)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        audioView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: audioView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: audioView.centerYAnchor)
        ])
        titleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.font = .systemFont(ofSize: 10)
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        containerView.addGestureRecognizer(panGesture!)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        containerView.addGestureRecognizer(tap)
    }
    
    func show() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        view.frame = CGRect(x: keyWindow.bounds.width - 170, y: 100, width: 150, height: 180)
        keyWindow.addSubview(view)
        view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.view.transform = .identity
        }
    }
    
    func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.view.alpha = 0
            self.view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }) { _ in
            self.view.removeFromSuperview()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = view.superview else { return }
        let translation = gesture.translation(in: superview)
        switch gesture.state {
        case .changed:
            view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
        case .ended:
            let finalX: CGFloat
            if view.center.x < superview.bounds.width / 2 {
                finalX = view.frame.width / 2 + 10
            } else {
                finalX = superview.bounds.width - view.frame.width / 2 - 10
            }
            UIView.animate(withDuration: 0.3) {
                self.view.center = CGPoint(x: finalX, y: self.view.center.y)
            }
        default: break
        }
    }
    
    @objc private func handleTap() {
        originalViewController?.floatingWindowDidTap()
    }
    
    @objc func restoreToFullscreenView() {
        _ = restoreToFullscreen()
    }
    
    @discardableResult
    func restoreToFullscreen() -> FloatingWindowCompatible? {
        guard let vc = originalViewController else { return nil }
        var videoSubview: UIView?
        if vc.isVideoCall {
            videoSubview = videoView.subviews.first
        }
        vc.restoreFromFloatingWindow(videoSubview)
        hide()
        return vc
    }
    
    @objc private func closeCall() {
        originalViewController?.endCallFromFloatingWindow()
        hide()
    }
    
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    private func updateDuration() {
        guard let duration = originalViewController?.getCurrentCallDuration() else { return }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
}
