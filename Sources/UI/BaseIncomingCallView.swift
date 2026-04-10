//
//  BaseIncomingCallView.swift
//  CallCore
//
//  Created by CallCore on 2026/4/7.
//

import UIKit

/// 来电弹窗代理
public protocol IncomingCallViewDelegate: AnyObject {
    func incomingCallViewDidAccept(_ view: BaseIncomingCallView)
    func incomingCallViewDidReject(_ view: BaseIncomingCallView)
}

/// 来电弹窗基类
open class BaseIncomingCallView: UIView {
    
    // MARK: - 公共属性
    public weak var delegate: IncomingCallViewDelegate?
    
    /// 来电用户
    public var callUser: CallUser?
    /// 通话类型
    public var callType: CallType = .voice
    /// 头像URL（可选）
    public var avatarURL: URL?
    
    // MARK: - UI 组件（子类可访问和修改）
    public let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        return view
    }()
    
    public let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 25
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = .systemGray2
        return iv
    }()
    
    public let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .left
        return label
    }()
    
    public let callTypeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .lightGray
        label.textAlignment = .left
        return label
    }()
    
    public let acceptButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "phone.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .systemGreen
        btn.layer.cornerRadius = 25
        return btn
    }()
    
    public let rejectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .systemRed
        btn.layer.cornerRadius = 25
        return btn
    }()
    
    // MARK: - 初始化
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI 设置（子类可重写以自定义布局）
    open func setupUI() {
        addSubview(containerView)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(callTypeLabel)
        containerView.addSubview(acceptButton)
        containerView.addSubview(rejectButton)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        callTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        rejectButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 默认约束：在屏幕顶部，左右留有边距，高度固定
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerView.topAnchor.constraint(equalTo: safeTopAnchor, constant: 12),
            containerView.heightAnchor.constraint(equalToConstant: 80),
            
            avatarImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 50),
            avatarImageView.heightAnchor.constraint(equalToConstant: 50),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: acceptButton.leadingAnchor, constant: -12),
            
            callTypeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            callTypeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            callTypeLabel.trailingAnchor.constraint(lessThanOrEqualTo: acceptButton.leadingAnchor, constant: -12),
            
            acceptButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            acceptButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            acceptButton.widthAnchor.constraint(equalToConstant: 50),
            acceptButton.heightAnchor.constraint(equalToConstant: 50),
            
            rejectButton.trailingAnchor.constraint(equalTo: acceptButton.leadingAnchor, constant: -12),
            rejectButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            rejectButton.widthAnchor.constraint(equalToConstant: 50),
            rejectButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    open func setupActions() {
        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)
    }
    
    // MARK: - 按钮事件
    @objc open func acceptTapped() {
        delegate?.incomingCallViewDidAccept(self)
    }
    
    @objc open func rejectTapped() {
        delegate?.incomingCallViewDidReject(self)
    }
    
    // MARK: - 数据更新
    open func configure(with user: CallUser, callType: CallType) {
            self.callUser = user
            self.callType = callType
            nameLabel.text = user.name
            callTypeLabel.text = callType == .video ? "视频通话" : "语音通话"
            // 可根据 user.avatar 加载头像
            if !user.avatar.isEmpty, let url = URL(string: user.avatar) {
                loadAvatar(from: url)
            } else {
                avatarImageView.image = UIImage(systemName: "person.circle.fill")
            }
        }
    
    open func loadAvatar(from url: URL) {
        // 默认使用系统头像，子类可重写实现网络加载
        avatarImageView.image = UIImage(systemName: "person.circle.fill")
    }
    
    // MARK: - 显示与隐藏动画
    open func show(in view: UIView, completion: (() -> Void)? = nil) {
        self.alpha = 0
        self.transform = CGAffineTransform(translationX: 0, y: -88)
        view.addSubview(self)
        self.frame = view.bounds
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            completion?()
        }
    }
    
    open func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -200)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
    
    // 辅助获取安全区域顶部
    private var safeTopAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11.0, *) {
            return self.safeAreaLayoutGuide.topAnchor
        } else {
            return self.topAnchor
        }
    }
}
