//
//  IncomingCallManager.swift
//  CallCore
//
//  Created by CallCore on 2026/4/7.
//

import UIKit

/// 来电弹窗管理器
public class IncomingCallManager {
    
    public static let shared = IncomingCallManager()
    
    private var currentView: BaseIncomingCallView?
    private weak var presentingView: UIView?
    
    private init() {}
    
    /// 显示来电弹窗
    /// - Parameters:
    ///   - view: 弹窗视图（可自定义子类）
    ///   - parentView: 父视图（默认 keyWindow）
    public func show(_ view: BaseIncomingCallView, in parentView: UIView? = nil) {
        hide()
        currentView = view
        let targetView = parentView ?? UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first
        guard let targetView = targetView else { return }
        presentingView = targetView
        view.show(in: targetView)
    }
    
    /// 隐藏当前弹窗
    public func hide() {
        currentView?.hide()
        currentView = nil
    }
    
    /// 是否正在显示弹窗
    public var isShowing: Bool {
        return currentView != nil
    }
}
