//
//  CallConfigurationExamples.swift
//  Example
//
//  CallKit 和 LiveCommunicationKit 配置示例
//

import Foundation
import AgoraCallKit

// MARK: - 配置模式枚举

/// 系统来电界面配置模式
enum CallKitMode {
    /// 仅使用 App 内弹窗（不启用系统来电界面）
    case appOnly
    
    /// 启用 CallKit（所有 iOS 版本使用）
    case callKitOnly
    
    /// 启用 LiveCommunicationKit（iOS 17.4+ 使用，规避审核风险）
    case liveCommunicationKit
    
    /// 仅 VoIP 推送时使用系统来电界面（动态控制）
    case voipPushOnly
}

// MARK: - 配置管理器

class CallConfigurationExamples {
    
    /// 配置系统来电界面
    /// - Parameter mode: 配置模式
    static func configure(mode: CallKitMode) {
        switch mode {
        case .appOnly:
            // 方式一：仅使用 App 内弹窗
            CallConfiguration.shared.isCallKitEnabled = false
            CallConfiguration.shared.isLiveCommunicationKitEnabled = false
            print("[配置] App 内弹窗模式")
            
        case .callKitOnly:
            // 方式二：启用 CallKit
            CallConfiguration.shared.isCallKitEnabled = true
            CallConfiguration.shared.isLiveCommunicationKitEnabled = false
            print("[配置] CallKit 模式")
            
        case .liveCommunicationKit:
            // 方式三：启用 LiveCommunicationKit（iOS 17.4+ 推荐）
            CallConfiguration.shared.isCallKitEnabled = true
            CallConfiguration.shared.isLiveCommunicationKitEnabled = true
            print("[配置] LiveCommunicationKit 模式")
            
        case .voipPushOnly:
            // 方式四：默认禁用，仅 VoIP 推送时启用
            CallConfiguration.shared.isCallKitEnabled = false
            CallConfiguration.shared.isLiveCommunicationKitEnabled = true
            print("[配置] VoIP 推送触发模式")
        }
    }
    
    /// 配置铃声
    /// - Parameters:
    ///   - ringtoneName: 铃声文件名（如 "ringtone_call.caf"）
    ///   - useCallSoundService: 是否同步设置 CallSoundService
    static func configureRingtone(_ ringtoneName: String, useCallSoundService: Bool = true) {
        // 设置系统来电界面铃声
        CallConfiguration.shared.callKitRingtoneSound = ringtoneName
        
        // 同步设置 CallSoundService（App 内来电彩铃）
        if useCallSoundService {
            if let path = Bundle.main.path(forResource: ringtoneName, ofType: nil) {
                CallSoundService.shared.incomingRingtonePath = path
            }
        }
        
        print("[配置] 铃声: \(ringtoneName)")
    }
    
    /// 配置角标图标
    /// - Parameter iconName: 图标名称（Assets.xcassets 中的名字）
    static func configureIcon(_ iconName: String) {
        CallConfiguration.shared.callKitIconName = iconName
        print("[配置] 图标: \(iconName)")
    }
    
    /// 检查当前系统来电界面类型
    static func checkCurrentFramework() -> String {
        if #available(iOS 17.4, *) {
            if CallConfiguration.shared.isLiveCommunicationKitEnabled {
                return "LiveCommunicationKit"
            }
        }
        if CallConfiguration.shared.isCallKitEnabled {
            return "CallKit"
        }
        return "App 内弹窗"
    }
}

// MARK: - 配置状态查看

extension CallConfigurationExamples {
    
    /// 打印当前配置状态
    static func printCurrentConfiguration() {
        print("========== 当前配置状态 ==========")
        print("isCallKitEnabled: \(CallConfiguration.shared.isCallKitEnabled)")
        print("isLiveCommunicationKitEnabled: \(CallConfiguration.shared.isLiveCommunicationKitEnabled)")
        
        if let ringtone = CallConfiguration.shared.callKitRingtoneSound {
            print("callKitRingtoneSound: \(ringtone)")
        } else {
            print("callKitRingtoneSound: (系统默认)")
        }
        
        if let icon = CallConfiguration.shared.callKitIconName {
            print("callKitIconName: \(icon)")
        } else {
            print("callKitIconName: (系统默认)")
        }
        
        print("当前框架: \(checkCurrentFramework())")
        print("==================================")
    }
}
