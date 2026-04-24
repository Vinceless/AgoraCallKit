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
    
    // MARK: - VoIP 来电框架配置
    
    /// 是否启用 LiveCommunicationKit（iOS 17.4+ VoIP 来电框架）
    /// - true: iOS 17.4+ 使用 LiveCommunicationKit（规避 CallKit 审核风险）
    ///   - iOS < 17.4 时，如果 isCallKitEnabled = true 则回退使用 CallKit
    /// - false: 不使用 LiveCommunicationKit，由 isCallKitEnabled 控制 CallKit
    /// - 注意：此配置独立于 isCallKitEnabled，设为 true 时 iOS 17.4+ 优先使用 LiveCommunicationKit
    /// - 默认值: false
    public var isLiveCommunicationKitEnabled: Bool = false
    
    /// 是否启用系统来电界面（CallKit 或 LiveCommunicationKit）
    /// - true: 收到来电时显示系统来电 UI，支持锁屏/后台接听
    ///   - iOS 17.4+: 如果 isLiveCommunicationKitEnabled = true 则优先用 LiveCommunicationKit
    ///   - 其他版本或 isLiveCommunicationKitEnabled = false 时使用 CallKit
    /// - false: 不使用任何系统来电界面，来电仅通过 App 内 uiDelegate 处理
    /// - 默认值: true
    public var isCallKitEnabled: Bool = true
    
    /// CallKit/LiveCommunicationKit 角标图标名（App 内资源，可选）
    public var callKitIconName: String?
    
    /// CallKit 来电铃声文件名（App Bundle 内的音频文件，如 "ringtone_call.caf"）
    /// - 设置后，系统来电界面将使用指定的音频文件作为铃声
    /// - 支持格式：Core Audio 支持的格式（.caf, .aiff, .wav, .mp3 等）
    /// - 建议铃声时长 1-30 秒
    /// - 默认为 nil，表示使用系统默认铃声
    public var callKitRingtoneSound: String?
    
    // MARK: - VoIP 推送配置
    
    /// 是否启用 VoIP 推送自动注册
    /// - true: App 调用 VoIPPushManager.shared.registerForVoIPPush() 后自动处理来电
    /// - false: 不使用 VoIP 推送，来电通过其他方式（如 Socket）触发
    /// - 默认值: true
    public var isVoIPPushEnabled: Bool = true
}
