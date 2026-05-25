//
//  UIWindowScene+KeyWindow.swift
//  AgoraCallKit
//
//  安全获取 keyWindow，替代废弃的 UIApplication.shared.windows
//

import UIKit

extension UIWindowScene {
    /// 当前聚焦的 window scene
    static var focused: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
    
    /// 安全获取 key window，iOS 15+ 使用原生属性，低版本遍历
    static var safeKeyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return UIWindowScene.focused?.keyWindow
        } else {
            return UIWindowScene.focused?.windows.first { $0.isKeyWindow }
        }
    }
}
