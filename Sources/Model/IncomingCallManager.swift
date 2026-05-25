//
//  IncomingCallManager.swift
//  AgoraCallCore
//
//  Created by CallCore on 2026/4/7.
//

import UIKit

/// 来电弹窗管理器，负责全局显示和隐藏来电弹窗
public class IncomingCallManager {
    
    public static let shared = IncomingCallManager()
    
    private var currentView: BaseIncomingCallView?
    private weak var presentingView: UIView?
    private let lock = NSLock()
    
    private init() {}
    
    /// 显示来电弹窗
    /// - Parameters:
    ///   - view: 弹窗视图（可自定义子类）
    ///   - parentView: 父视图（默认 keyWindow）
    public func show(_ view: BaseIncomingCallView, in parentView: UIView? = nil) {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(view, in: parentView)
            }
            return
        }
        
        lock.lock()
        hide()
        currentView = view
        let targetView = parentView ?? firstWindow
        guard let targetView = targetView else {
            lock.unlock()
            return
        }
        presentingView = targetView
        lock.unlock()
        
        view.show(in: targetView)
    }
    
    var firstWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes.filter { $0.activationState == .foregroundActive }.compactMap { $0 as? UIWindowScene }.last?.windows.last(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    
    /// 隐藏当前弹窗
    public func hide() {
        lock.lock()
        defer { lock.unlock() }
        currentView?.hide()
        currentView = nil
    }
    
    /// 是否正在显示弹窗
    public var isShowing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentView != nil
    }
}
