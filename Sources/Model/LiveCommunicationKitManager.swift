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
            print("[LiveCommunicationKitManager] LiveCommunicationKit 未启用，跳过配置")
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
        
        print("[LiveCommunicationKitManager] ConversationManager 配置完成")
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
        print("[LiveCommunicationKitManager] reportIncomingCall 开始: uuid=\(uuid), callerName=\(callerName), isVideo=\(isVideo)")
        
        guard LiveCommunicationKitManager.isEnabled else {
            print("[LiveCommunicationKitManager] LiveCommunicationKit 未启用，跳过报告来电")
            completion(false)
            return
        }
        
        guard let conversationManager = conversationManager else {
            print("[LiveCommunicationKitManager] ConversationManager 未初始化，请先调用 configure()")
            completion(false)
            return
        }
        
        currentCallUUID = uuid
        
        // 创建 Handle 表示来电者
        let handle = Handle(type: .generic, value: callerName, displayName: callerName)
        
        // 创建 Update 配置来电信息
        var update = Conversation.Update()
        update.members = [handle]
        
        print("[LiveCommunicationKitManager] 开始报告新来电 (Live Activity)...")
        
        // 关键：不使用 Task 包装，直接在当前线程执行
        // 这样可以确保在 PKPushRegistry delegate 返回前完成执行
        Task {
            do {
                try await conversationManager.reportNewIncomingConversation(uuid: uuid, update: update)
                print("[LiveCommunicationKitManager] ✅ Live Activity 来电界面已显示")
                await MainActor.run {
                    self.isShowingIncomingCall = true
                    completion(true)
                }
            } catch {
                print("[LiveCommunicationKitManager] ❌ 报告来电失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isShowingIncomingCall = false
                    completion(false)
                }
            }
        }
        
        Thread.sleep(forTimeInterval: 0.05)
    }
    
    // MARK: - 通话状态报告
    
    /// 报告通话已接通
    public func reportCallConnected() {
        guard let conversation = currentConversation else {
            print("[LiveCommunicationKitManager] 当前没有通话，无法报告接通")
            return
        }
        
        let event = Conversation.Event.conversationConnected(Date())
        conversationManager?.reportConversationEvent(event, for: conversation)
        print("[LiveCommunicationKitManager] 通话已接通")
    }
    
    /// 报告通话已结束
    public func reportCallEnded(reason: String = "ended") {
        guard let conversation = currentConversation else {
            print("[LiveCommunicationKitManager] 当前没有通话，无法报告结束")
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
        print("[LiveCommunicationKitManager] 通话已结束: \(reason)")
        
        // 清理状态
        currentConversation = nil
        isShowingIncomingCall = false
    }
    
    // MARK: - 主动操作
    
    /// 主动结束通话
    public func endCall() {
        reportCallEnded(reason: "userEnded")
    }
    
    /// 标记为已接听
    public func markCallAccepted() {
        isShowingIncomingCall = false
        if let action = pendingAction {
            action.fulfill()
            pendingAction = nil
        }
    }
    
    /// 标记为已拒绝
    public func markCallRejected() {
        isShowingIncomingCall = false
        if let action = pendingAction {
            action.fail()
            pendingAction = nil
        }
        currentConversation = nil
        currentCallUUID = nil
    }
}

// MARK: - ConversationManagerDelegate

@available(iOS 17.4, *)
extension LiveCommunicationKitManager: ConversationManagerDelegate {
    
    /// Conversation 开始
    public func conversationManagerDidBegin(_ manager: ConversationManager) {
        print("[LiveCommunicationKitManager] ConversationManager 开始")
    }
    
    /// ConversationManager 重置
    public func conversationManagerDidReset(_ manager: ConversationManager) {
        print("[LiveCommunicationKitManager] ConversationManager 重置")
        currentConversation = nil
        isShowingIncomingCall = false
        delegate?.liveCommunicationKitDidReset()
    }
    
    /// Conversation 变化
    public func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
        print("[LiveCommunicationKitManager] Conversation 变化: \(conversation.state)")
        currentConversation = conversation
    }
    
    /// 需要执行 Action
    public func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        print("[LiveCommunicationKitManager] 执行 Action: \(type(of: action)), uuid=\(action.uuid)")
        
        // 根据 Action 类型处理
        if action is JoinConversationAction {
            pendingAction = action
            delegate?.liveCommunicationKitDidAcceptCall(uuid: action.uuid) { success in
                if success {
                    self.markCallAccepted()
                } else {
                    self.markCallRejected()
                }
            }
        } else if action is EndConversationAction {
            // 保存 pendingAction 用于状态管理
            pendingAction = action
            
            // 检查当前 Conversation 状态
            if let conversation = currentConversation {
                print("[LiveCommunicationKitManager] EndConversationAction: conversation.state=\(conversation.state)")
                
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
                print("[LiveCommunicationKitManager] EndConversationAction: currentConversation 为空")
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
        print("[LiveCommunicationKitManager] Action 超时: \(type(of: action))")
        delegate?.liveCommunicationKitDidTimeout(uuid: action.uuid)
        action.fail()
        pendingAction = nil
    }
    
    /// 音频会话激活
    public func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
        print("[LiveCommunicationKitManager] 音频会话激活")
    }
    
    /// 音频会话停用
    public func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
        print("[LiveCommunicationKitManager] 音频会话停用")
    }
}
