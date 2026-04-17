//
//  CallConfiguration.swift
//  AgoraCallKit
//
//  通话配置项：控制 CallKit、VoIP 推送等功能的开关
//

import Foundation

/// 通话配置（全局单例），App 启动时设置各项开关
public class CallConfiguration {
    
    public static let shared = CallConfiguration()
    
    private init() {}
    
    // MARK: - CallKit 配置
    
    /// 是否启用 CallKit（系统来电界面）
    /// - true: 收到来电时通过 CXProvider 显示系统来电 UI，支持锁屏/后台接听
    /// - false: 不使用 CallKit，来电仅通过 App 内 uiDelegate 处理（默认通知模式）
    /// - 默认值: true
    public var isCallKitEnabled: Bool = true
    
    /// CallKit 角标图标名（App 内资源，可选）
    public var callKitIconName: String?
    
    // MARK: - VoIP 推送配置
    
    /// 是否启用 VoIP 推送自动注册
    /// - true: App 调用 VoIPPushManager.shared.registerForVoIPPush() 后自动处理来电
    /// - false: 不使用 VoIP 推送，来电通过其他方式（如 Socket）触发
    /// - 默认值: true
    public var isVoIPPushEnabled: Bool = true
}
