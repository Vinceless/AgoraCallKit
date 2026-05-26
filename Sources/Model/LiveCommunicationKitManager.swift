//
//  LiveCommunicationKitManager.swift
//  AgoraCallKit
//
//  Apple LiveCommunicationKit 集成：iOS 17.4+ 可用的 VoIP 通话界面框架
//  用于在锁屏上显示 Live Activity 形式的来电界面
//
//  重要配置：
//  1. Info.plist 需要添加 NSSupportsLiveActivities = YES
//  2. 需要有 Live Activity Widget Extension
//
//  与 PKPushRegistry 配合使用注意事项：
//  - PKPushRegistry 的 delegate 必须在返回前完成来电报告
//  - 不能使用 Task { } 包装 async 方法，否则会导致时序问题
//  - 参考: Apple Bug FB16655952 - PushKit async delegate broken
//

import Foundation
import LiveCommunicationKit
import AVFoundation

/// LiveCommunicationKit 事件委托
public protocol LiveCommunicationKitManagerDelegate: AnyObject {
    /// 用户点击了接听
    func liveCommunicationKitDidAcceptCall(uuid: UUID, completion: @escaping (Bool) -> Void)
    /// 用户点击了拒绝
    func liveCommunicationKitDidRejectCall(uuid: UUID)
    /// 通话超时未接听
    func liveCommunicationKitDidTimeout(uuid: UUID)
    /// 重置
    func liveCommunicationKitDidReset()
}

/// LiveCommunicationKit 管理器（iOS 17.4+）
/// 用于在锁屏上显示 Live Activity 形式的来电界面
///
/// 重要说明：
/// - LiveCommunicationKit 不能替代 CallKit 处理 VoIP 推送（PKPushRegistry 强制要求 CallKit）
/// - 建议配合使用：CallKit 报告来电满足系统要求 + LiveCommunicationKit 显示 Live Activity
@available(iOS 17.4, *)
public class LiveCommunicationKitManager: NSObject {
    
    public static let shared = LiveCommunicationKitManager()
    
    public weak var delegate: LiveCommunicationKitManagerDelegate?
    
    /// ConversationManager 实例
    private var conversationManager: ConversationManager?
    
    /// 当前通话的 Conversation
    private var currentConversation: Conversation?
    
    /// 当前通话的 UUID
    private var currentCallUUID: UUID?
    
    /// 是否正在显示来电界面
    public private(set) var isShowingIncomingCall = false
    
    private var pendingAction: ConversationAction?  // 存储待处理的 Action，用于延迟 fulfill
    
    /// 是否正在执行 reportIncomingCall（用于区分 reset 原因是"展现失败"还是"通话结束"）
    private var isReportingIncomingCall = false
    /// 当前 reportIncomingCall 的 completion 回调（用于在展现失败时通知 CallManager 降级）
    private var reportCompletion: ((Bool) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 配置检查
    
    /// 检查是否应该使用 LiveCommunicationKit
    public static var isEnabled: Bool {
        return CallConfiguration.shared.isLiveCommunicationKitEnabled
    }
    
    // MARK: - 初始化
    
    /// 配置并创建 ConversationManager
    /// - Important: 必须在 App 启动时调用，且 LiveCommunicationKit 必须在通话到来前初始化
    public func configure() {
        guard LiveCommunicationKitManager.isEnabled else {
            AgoraLogger.info("LiveCommunicationKit 未启用，跳过配置", module: "LiveCommunicationKit")
            return
        }
        
        // 创建配置
        var config = ConversationManager.Configuration(
            ringtoneName: nil,
            iconTemplateImageData: nil,
            maximumConversationGroups: 1,
            maximumConversationsPerConversationGroup: 1,
            includesConversationInRecents: true,
            supportsVideo: true,
            supportedHandleTypes: [.generic]
        )
        
        // 配置铃声
        if let ringtoneSound = CallConfiguration.shared.callKitRingtoneSound {
            config.ringtoneName = ringtoneSound
        } else if let incomingPath = CallSoundService.shared.incomingRingtonePath {
            config.ringtoneName = (incomingPath as NSString).lastPathComponent
        }
        
        // 配置图标
        if let iconName = CallConfiguration.shared.callKitIconName,
           let imageData = UIImage(named: iconName)?.pngData() {
            config.iconTemplateImageData = imageData
        }
        
        // 创建 ConversationManager
        conversationManager = ConversationManager(configuration: config)
        conversationManager?.delegate = self
        
        AgoraLogger.info("ConversationManager 配置完成", module: "LiveCommunicationKit")
    }
    
    // MARK: - 报告来电
    
    /// 向系统报告收到来电（用于显示 Live Activity 来电界面）
    ///
    /// ⚠️ 重要：此方法在 PKPushRegistry delegate 中调用时，必须确保在返回前完成执行
    /// 不要使用 Task { } 包装此调用，否则会导致时序问题（参考 Apple Bug FB16655952）
    ///
    /// - Parameters:
    ///   - uuid: 通话唯一标识
    ///   - callerName: 主叫方名称
    ///   - callerAvatar: 主叫方头像数据（可选）
    ///   - isVideo: 是否为视频通话
    ///   - completion: 报告完成回调
    public func reportIncomingCall(uuid: UUID, callerName: String, callerAvatar: Data? = nil, isVideo: Bool, completion: @escaping (Bool) -> Void) {
        AgoraLogger.info("reportIncomingCall 开始: uuid=\(uuid), callerName=\(callerName), isVideo=\(isVideo)", module: "LiveCommunicationKit")
        
        guard LiveCommunicationKitManager.isEnabled else {
            AgoraLogger.info("LiveCommunicationKit 未启用，跳过报告来电", module: "LiveCommunicationKit")
            completion(false)
            return
        }
        
        guard let conversationManager = conversationManager else {
            AgoraLogger.info("ConversationManager 未初始化，请先调用 configure()", module: "LiveCommunicationKit")
            completion(false)
            return
        }
        
        currentCallUUID = uuid
        isReportingIncomingCall = true
        reportCompletion = completion
        
        // 创建 Handle 表示来电者
        let handle = Handle(type: .generic, value: callerName, displayName: callerName)
        
        // 创建 Update 配置来电信息
        var update = Conversation.Update()
        update.members = [handle]
        
        AgoraLogger.info("开始报告新来电 (Live Activity)...", module: "LiveCommunicationKit")
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await conversationManager.reportNewIncomingConversation(uuid: uuid, update: update)
                AgoraLogger.info("✅ Live Activity 来电界面已显示", module: "LiveCommunicationKit")
                await MainActor.run {
                    self.isShowingIncomingCall = true
                    self.isReportingIncomingCall = false
                    completion(true)
//                    self.reportCompletion = nil
                }
            } catch {
                AgoraLogger.error("❌ 报告来电失败: \(error.localizedDescription)", module: "LiveCommunicationKit")
                await MainActor.run {
                    self.isShowingIncomingCall = false
                    self.isReportingIncomingCall = false
                    self.currentCallUUID = nil
                    self.currentConversation = nil
                    completion(false)
//                    self.reportCompletion = nil
                }
            }
        }
        
    }
    
    // MARK: - 通话状态报告
    
    /// 报告通话已接通
    public func reportCallConnected() {
        guard let conversation = currentConversation else {
            AgoraLogger.info("当前没有通话，无法报告接通", module: "LiveCommunicationKit")
            return
        }
        
        let event = Conversation.Event.conversationConnected(Date())
        conversationManager?.reportConversationEvent(event, for: conversation)
        AgoraLogger.info("通话已接通", module: "LiveCommunicationKit")
    }
    
    /// 报告通话已结束
    public func reportCallEnded(reason: String = "ended") {
        guard let conversation = currentConversation else {
            AgoraLogger.info("当前没有通话，无法报告结束", module: "LiveCommunicationKit")
            return
        }
        
        let endedReason: Conversation.EndedReason
        switch reason {
        case "failed":
            endedReason = .failed
        case "remoteEnded":
            endedReason = .remoteEnded
        default:
            endedReason = .unanswered
        }
        
        let event = Conversation.Event.conversationEnded(Date(), endedReason)
        conversationManager?.reportConversationEvent(event, for: conversation)
        AgoraLogger.info("通话已结束: \(reason)", module: "LiveCommunicationKit")
        
        // 清理状态
        currentConversation = nil
        isShowingIncomingCall = false
    }
    
    // MARK: - 主动操作
    
    /// 主动结束通话
    public func endCall() {
        reportCallEnded(reason: "userEnded")
    }
    
    /// 标记为已接听（作为非 delegate 路径的后备方法）
    /// 例如用户在应用进入前台后在应用内接听电话时调用
    public func markCallAccepted() {
        isShowingIncomingCall = false
        guard let action = pendingAction else {
            // 已经通过 completion 完成，或者已超时 — 安全忽略
            AgoraLogger.info("markCallAccepted: pendingAction 已为 nil，跳过", module: "LiveCommunicationKit")
            return
        }
        action.fulfill()
        pendingAction = nil
    }
    
    /// 标记为已拒绝（作为非 delegate 路径的后备方法）
    /// 例如用户在应用进入前台后在应用内拒绝电话时调用
    public func markCallRejected() {
        isShowingIncomingCall = false
        if let action = pendingAction {
            action.fail()
            pendingAction = nil
        } else {
            AgoraLogger.info("markCallRejected: pendingAction 已为 nil，跳过", module: "LiveCommunicationKit")
        }
        currentConversation = nil
        currentCallUUID = nil
    }
    
    /// 关闭来电界面（App 进入前台时调用，隐藏 Live Activity 来电界面）
    public func dismissIncomingCallUI() {
        AgoraLogger.info("dismissIncomingCallUI: isShowingIncomingCall=\(isShowingIncomingCall), pendingAction=\(pendingAction != nil)", module: "LiveCommunicationKit")
        
        // 标记为不再显示
        isShowingIncomingCall = false
        
        // 如果有待处理的 action，说明用户已经在系统 UI 点击了
        if let action = pendingAction {
            if action is JoinConversationAction {
                // 用户点击了接听，标记为接受并关闭 Live Activity
                AgoraLogger.info("dismissIncomingCallUI: 用户已点击接听，关闭 Live Activity", module: "LiveCommunicationKit")
                action.fulfill()
            } else if action is EndConversationAction {
                // 用户点击了拒绝，标记为拒绝并关闭 Live Activity
                AgoraLogger.info("dismissIncomingCallUI: 用户已点击拒绝，关闭 Live Activity", module: "LiveCommunicationKit")
                action.fail()
            }
            pendingAction = nil
            return
        }
        
        // 没有待处理的 action，说明用户还没操作
        // 尝试强制关闭 Live Activity
        AgoraLogger.info("dismissIncomingCallUI: 用户还未操作，尝试强制关闭", module: "LiveCommunicationKit")
        
        if let conversation = currentConversation {
            AgoraLogger.info("使用 currentConversation 结束", module: "LiveCommunicationKit")
            let event = Conversation.Event.conversationEnded(Date(), .unanswered)
            conversationManager?.reportConversationEvent(event, for: conversation)
            currentConversation = nil
        } else {
            AgoraLogger.info("currentConversation 为 nil，尝试结束所有活动通话", module: "LiveCommunicationKit")
            // 最后手段：结束所有 active conversations
        }
    }
}

// MARK: - ConversationManagerDelegate

@available(iOS 17.4, *)
extension LiveCommunicationKitManager: ConversationManagerDelegate {
    
    /// Conversation 开始
    public func conversationManagerDidBegin(_ manager: ConversationManager) {
        AgoraLogger.info("ConversationManager 开始", module: "LiveCommunicationKit")
    }
    
    /// ConversationManager 重置
    public func conversationManagerDidReset(_ manager: ConversationManager) {
        AgoraLogger.info("ConversationManager 重置, isReportingIncomingCall=\(isReportingIncomingCall), isShowingIncomingCall=\(isShowingIncomingCall)", module: "LiveCommunicationKit")
        
        // 场景1：正在 reportIncomingCall 过程中被重置 → 说明 Live Activity 展现失败
        // 仅通知 completion(false)，让 CallManager 回退到 in-app UI，不结束通话
        if isReportingIncomingCall {
            AgoraLogger.info("重置发生在报告来电过程中，通知 CallManager 降级到 in-app UI", module: "LiveCommunicationKit")
            isReportingIncomingCall = false
            currentConversation = nil
            isShowingIncomingCall = false
            let completion = reportCompletion
            reportCompletion = nil
            currentCallUUID = nil
            completion?(false)
            return
        }
        
        // 场景2：已显示来电界面后被重置（如用户在其他地方结束通话、系统回收资源等）
        // 通知 CallManager 处理
        currentConversation = nil
        isShowingIncomingCall = false
        delegate?.liveCommunicationKitDidReset()
    }
    
    /// Conversation 变化
    public func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
        AgoraLogger.info("Conversation 变化: \(conversation.state)", module: "LiveCommunicationKit")
        currentConversation = conversation
    }
    
    /// 需要执行 Action
    public func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        AgoraLogger.info("执行 Action: \(type(of: action)), uuid=\(action.uuid)", module: "LiveCommunicationKit")
        
        // 根据 Action 类型处理
        if action is JoinConversationAction {
            pendingAction = action
            delegate?.liveCommunicationKitDidAcceptCall(uuid: action.uuid) { [weak self] success in
                guard let self = self else { return }
                if success {
                    // 直接在闭包中捕获并 fulfill action，不依赖 pendingAction 属性
                    // 这样可以避免异步间隙期间 pendingAction 被清除导致 action 无法完成
                    action.fulfill()
                    self.pendingAction = nil
                    self.isShowingIncomingCall = false
                } else {
                    action.fail()
                    self.pendingAction = nil
                }
            }
        } else if action is EndConversationAction {
            // 保存 pendingAction 用于状态管理
            pendingAction = action
            
            // 检查当前 Conversation 状态
            if let conversation = currentConversation {
                AgoraLogger.info("EndConversationAction: conversation.state=\(conversation.state)", module: "LiveCommunicationKit")
                
                // 根据 Conversation 状态决定操作
                // .idle/.joining: 通话尚未接通，用户拒绝来电
                // .joined: 通话已接通，用户挂断通话
                switch conversation.state {
                case .idle, .joining:
                    // 拒绝来电 - 通知 delegate 并标记为失败
                    delegate?.liveCommunicationKitDidRejectCall(uuid: action.uuid)
                    action.fail()
                case .joined, .paused:
                    // 挂断通话 - 通知 delegate
                    delegate?.liveCommunicationKitDidRejectCall(uuid: action.uuid)
                    action.fulfill()
                default:
                    // .leaving, .left 等其他状态
                    action.fulfill()
                }
            } else {
                // 没有 Conversation 记录，仍然通知 delegate
                AgoraLogger.info("EndConversationAction: currentConversation 为空", module: "LiveCommunicationKit")
                delegate?.liveCommunicationKitDidRejectCall(uuid: action.uuid)
                action.fail()
            }
        } else if action is MuteConversationAction {
            action.fulfill()
        } else if action is PauseConversationAction {
            action.fulfill()
        }
    }
    
    /// Action 超时
    public func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
        AgoraLogger.info("Action 超时: \(type(of: action))", module: "LiveCommunicationKit")
        delegate?.liveCommunicationKitDidTimeout(uuid: action.uuid)
        action.fail()
        pendingAction = nil
    }
    
    /// 音频会话激活
    public func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
        AgoraLogger.info("音频会话激活", module: "LiveCommunicationKit")
    }
    
    /// 音频会话停用
    public func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
        AgoraLogger.info("音频会话停用", module: "LiveCommunicationKit")
    }
}
