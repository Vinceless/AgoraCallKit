//
//  CallConfigurationExamples.swift
//  Example
//
//  CallKit 和 LiveCommunicationKit 配置示例
//

import Foundation
import AgoraCallKit

// MARK: - 配置管理器

class CallConfigurationExamples {
    
    /// 配置系统来电界面模式
    /// - Parameter mode: 系统来电界面模式
    static func configure(mode: SystemCallUI) {
        CallConfiguration.shared.configure(mode: mode)
        print("[配置] 系统来电界面模式: \(mode)")
    }
    
    /// 根据来电类型获取系统来电界面展示类型
    /// - Parameter type: 来电类型
    /// - Returns: 系统来电界面展示类型
    @discardableResult
    static func displayType(for type: IncomingCallType) -> SystemCallDisplayType {
        let result = CallConfiguration.shared.displayType(for: type)
        print("[配置] 来电类型: \(type), 展示类型: \(result)")
        return result
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
}

// MARK: - 配置示例

extension CallConfigurationExamples {
    
    /// 使用示例
    static func usageExamples() {
        // ========== 方式一：configure() - App 启动时配置 ==========
        
        // 仅使用 App 内弹窗
        CallConfiguration.shared.configure(mode: .none)
        
        // 仅使用 CallKit（所有 iOS 版本）
        CallConfiguration.shared.configure(mode: .callKitOnly)
        
        // 仅使用 LiveCommunicationKit（iOS 17.4+，规避审核风险）
        CallConfiguration.shared.configure(mode: .liveCommunicationKitOnly)
        
        // 优先使用 LiveCommunicationKit，iOS < 17.4 回退到 CallKit（推荐）
        CallConfiguration.shared.configure(mode: .auto)
        
        // 仅在 VoIP 推送时启用系统来电界面
        CallConfiguration.shared.configure(mode: .voipPushOnly)
        
        // ========== 方式二：displayType(for:) - 来电时获取展示类型 ==========
        
        // VoIP 推送来电：根据 SystemCallUI 配置决定展示类型
        let voipDisplayType = CallConfiguration.shared.displayType(for: .voIPPush)
        switch voipDisplayType {
        case .liveCommunicationKit:
            print("使用 LiveCommunicationKit")
        case .callKit:
            print("使用 CallKit")
        case .none:
            print("不使用系统来电界面")
        }
        
        // 普通来电：始终不显示系统来电界面
        let normalDisplayType = CallConfiguration.shared.displayType(for: .normal)
        if case .none = normalDisplayType {
            print("仅使用 App 内弹窗")
        }
        
        // ========== 方式三：链式调用 ==========
        CallConfiguration.shared
            .configure(mode: .auto)
            .callKitRingtoneSound = "ringtone_call.caf"
    }
}

// MARK: - 配置状态查看

extension CallConfigurationExamples {
    
    /// 打印当前配置状态
    static func printCurrentConfiguration() {
        print("========== 当前配置状态 ==========")
        print("系统来电界面模式: \(CallConfiguration.shared.systemCallUI)")
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
        
        print("当前框架: \(CallConfiguration.shared.currentFramework)")
        print("==================================")
    }
}
