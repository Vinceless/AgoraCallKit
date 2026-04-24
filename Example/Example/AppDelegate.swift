//
//  AppDelegate.swift
//  Example
//
//  Created by Vince on 2026/3/31.
//

import UIKit
import UserNotifications
import AgoraCallKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // ========== 通话服务初始化示例 ==========
        
        // 选择配置模式：
        // - .appOnly: 仅使用 App 内弹窗
        // - .callKitOnly: 启用 CallKit（所有 iOS 版本）
        // - .liveCommunicationKit: 启用 LiveCommunicationKit（iOS 17.4+）
        // - .voipPushOnly: 仅 VoIP 推送时使用系统来电界面（推荐）
        
        ExampleCallServiceManager.shared.setup(mode: .voipPushOnly)
        
        // ========== 请求通知权限（VoIP 推送需要） ==========
        requestNotificationPermission()
        
        return true
    }
    
    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    // MARK: - VoIP 推送处理
    
    /// 注册 VoIP 推送 DeviceToken
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // TODO: 将 deviceToken 发送到服务器
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[VoIP] DeviceToken: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[VoIP] 注册失败: \(error.localizedDescription)")
    }
    
    // MARK: - 私有方法
    
    private func requestNotificationPermission() {
        // 请求通知权限（用于普通推送，VoIP 推送不需要此权限）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("[通知] 权限请求失败: \(error.localizedDescription)")
            }
        }
    }
}
