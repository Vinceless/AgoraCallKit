//
//  CallConfiguration.swift
//  AgoraCallKit
//
//  通话配置项：控制 CallKit、VoIP 推送等功能的开关
//

import Foundation

// MARK: - 来电类型

/// 来电类型（用于来电时配置系统来电界面）
public enum IncomingCallType {
    /// VoIP 推送触发的来电（需要系统来电界面支持锁屏/后台唤醒）
    case voIPPush
    
    /// 普通来电（如 WebSocket 信令触发，不需要系统来电界面）
    case normal
}

// MARK: - 系统来电界面展示类型

/// 系统来电界面的展示类型（用于来电时确定实际使用的框架）
public enum SystemCallDisplayType {
    /// 不显示系统来电界面（仅 App 内弹窗）
    case none
    
    /// 使用 CallKit 展示来电界面
    case callKit
    
    /// 使用 LiveCommunicationKit 展示来电界面（iOS 17.4+）
    case liveCommunicationKit
}

// MARK: - 系统来电界面模式

/// 系统来电界面模式（高级 API，推荐使用）
public enum SystemCallUI {
    /// 不使用系统来电界面（仅 App 内弹窗）
    case none
    
    /// 仅使用 CallKit（所有 iOS 版本）
    case callKitOnly
    
    /// 仅使用 LiveCommunicationKit（iOS 17.4+，规避审核风险）
    /// - iOS < 17.4 时自动降级为 App 内弹窗
    case liveCommunicationKitOnly
    
    /// 优先使用 LiveCommunicationKit，iOS < 17.4 回退到 CallKit（推荐）
    /// - iOS 17.4+: 使用 LiveCommunicationKit（支持 VoIP 后台唤醒）
    /// - iOS < 17.4: 使用 CallKit（支持 VoIP 后台唤醒）
    case auto
    
    /// 仅在 VoIP 推送时启用系统来电界面（动态控制）
    /// - 收到 VoIP 推送时自动启用系统来电界面
    /// - 其他方式触发来电时不启用
    case voipPushOnly
    
    /// 当前是否启用系统来电界面
    var isEnabled: Bool {
        switch self {
        case .none:
            return false
        default:
            return true
        }
    }
}

/// 通话配置（全局单例），App 启动时设置各项开关
public class CallConfiguration {
    
    public static let shared = CallConfiguration()
    
    private init() {}
    
    // MARK: - 系统来电界面模式（推荐 API）
    
    /// 系统来电界面模式
    /// - 使用 configure(mode:) 设置
    public private(set) var systemCallUI: SystemCallUI = .auto
    
    /// 配置系统来电界面模式（推荐方式）
    /// - Parameter mode: 系统来电界面模式
    /// - Returns: 配置后的实例，方便链式调用
    @discardableResult
    public func configure(mode: SystemCallUI) -> CallConfiguration {
        systemCallUI = mode
        return self
    }
    
    /// 快速配置：仅在 VoIP 推送时启用系统来电界面
    /// - Returns: 配置后的实例，方便链式调用
    @discardableResult
    public func enableForVoIPPushOnly() -> CallConfiguration {
        systemCallUI = .voipPushOnly
        return self
    }
    
    // MARK: - 来电展示类型
    
    /// CallKit 是否在目标市场可用的编译时检查
    /// - 中国区 App Store 不允许使用 CallKit，因此 CHINA_APP_STORE 下始终返回 false
    private var callKitAvailable: Bool {
#if CHINA_APP_STORE
        return false
#else
        return true
#endif
    }
    
    /// 根据来电类型和当前 SystemCallUI 配置，返回系统来电界面展示类型
    /// - Parameter type: 来电类型（.voIPPush 或 .normal）
    /// - Returns: 系统来电界面展示类型（LiveCommunicationKit、CallKit 或 none）
    public func displayType(for type: IncomingCallType) -> SystemCallDisplayType {
        switch type {
        case .normal:
            // 普通来电：不显示系统来电界面
            switch systemCallUI {
            case .none, .voipPushOnly:
                return .none
            case .callKitOnly:
                return callKitAvailable ? .callKit : .none
            case .liveCommunicationKitOnly:
                if #available(iOS 17.4, *) {
                    return .liveCommunicationKit
                }
                return .none
            case .auto:
                if #available(iOS 17.4, *) {
                    return .liveCommunicationKit
                }
                return callKitAvailable ? .callKit : .none
            }
            
        case .voIPPush:
            // VoIP 推送来电
            switch systemCallUI {
            case .none:
                return .none
            case .callKitOnly:
                return callKitAvailable ? .callKit : .none
            case .liveCommunicationKitOnly:
                if #available(iOS 17.4, *) {
                    return .liveCommunicationKit
                }
                return .none
            case .auto, .voipPushOnly:
                if #available(iOS 17.4, *) {
                    return .liveCommunicationKit
                }
                return callKitAvailable ? .callKit : .none
            }
        }
    }
    
    // MARK: - 只读属性（根据 systemCallUI 计算）
    
    /// 是否启用 LiveCommunicationKit（iOS 17.4+ VoIP 来电框架）
    /// - 注意：LiveCommunicationKit 和 CallKit 都支持 VoIP 后台唤醒
    public var isLiveCommunicationKitEnabled: Bool {
        switch systemCallUI {
        case .none, .callKitOnly:
            return false
        case .liveCommunicationKitOnly, .auto, .voipPushOnly:
            if #available(iOS 17.4, *) {
                return true
            }
            return false
        }
    }
    
    /// 是否启用系统来电界面（CallKit 或 LiveCommunicationKit）
    /// - true: 收到来电时显示系统来电 UI，支持锁屏/后台接听
    /// - false: 不使用任何系统来电界面，来电仅通过 App 内 uiDelegate 处理
    public var isCallKitEnabled: Bool {
        guard callKitAvailable else { return false }
        switch systemCallUI {
        case .none, .liveCommunicationKitOnly:
            return false
        case .callKitOnly:
            return true
        case .auto, .voipPushOnly:
            if #available(iOS 17.4, *) {
                return false
            }
            return true
        }
    }
    
    /// 当前实际使用的系统来电框架
    public var currentFramework: String {
        if #available(iOS 17.4, *) {
            if isLiveCommunicationKitEnabled {
                return "LiveCommunicationKit"
            }
        }
        if isCallKitEnabled {
            return "CallKit"
        }
        return "App 内弹窗"
    }
    
    // MARK: - 外观配置
    
    /// 系统来电界面角标图标名（App 内资源，可选）
    public var callKitIconName: String?
    
    /// 系统来电界面铃声文件名（App Bundle 内的音频文件，如 "ringtone_call.caf"）
    /// - 支持格式：Core Audio 支持的格式（.caf, .aiff, .wav, .mp3 等）
    /// - 建议铃声时长 1-30 秒
    /// - 默认为 nil，表示使用系统默认铃声
    public var callKitRingtoneSound: String?
    
    // MARK: - VoIP 推送配置
    
    /// 是否启用 VoIP 推送自动注册
    /// - 默认值: true
    public var isVoIPPushEnabled: Bool = true
}
