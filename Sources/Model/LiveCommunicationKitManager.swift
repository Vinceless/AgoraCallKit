//
//  LiveCommunicationKitManager.swift
//  AgoraCallKit
//
//  Apple LiveCommunicationKit 集成：iOS 17.4+ 可用的 VoIP 通话界面框架
//  作为 CallKit 的替代方案，用于规避 CallKit 可能存在的 AppStore 审核风险
//

import Foundation
import LiveCommunicationKit
import AVFoundation

/// LiveCommunicationKit 事件委托
public protocol LiveCommunicationKitManagerDelegate: AnyObject {
    /// 用户点击了接听
    func liveCommunicationKitDidAcceptCall(uuid: UUID)
    /// 用户点击了拒绝
    func liveCommunicationKitDidRejectCall(uuid: UUID)
    /// 通话超时未接听
    func liveCommunicationKitDidTimeout(uuid: UUID)
}

/// LiveCommunicationKit 管理器（iOS 17.4+）
/// 用于替代 CallKit，提供更简洁的 VoIP 来电界面
/// LiveCommunicationKit 优势：
/// - 不需要配置 CXProvider，避免审核风险
/// - 界面更简洁，适合简单的一对一通话场景
/// - 支持 Live Activity 和动态岛（iOS 16.1+）
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
        
        // 配置铃声（复用 CallSoundService）
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
    
    /// 向系统报告收到来电（收到 VoIP 推送后调用）
    /// - Parameters:
    ///   - uuid: 通话唯一标识
    ///   - callerName: 主叫方名称
    ///   - isVideo: 是否为视频通话
    public func reportIncomingCall(uuid: UUID, callerName: String, isVideo: Bool) {
        guard LiveCommunicationKitManager.isEnabled else {
            print("[LiveCommunicationKitManager] LiveCommunicationKit 未启用，跳过报告来电")
            return
        }
        
        guard let conversationManager = conversationManager else {
            print("[LiveCommunicationKitManager] ConversationManager 未初始化，请先调用 configure()")
            return
        }
        
        currentCallUUID = uuid
        
        // 创建 Handle 表示来电者
        let handle = Handle(type: .generic, value: callerName, displayName: callerName)
        
        // 创建 Update 配置来电信息
        var update = Conversation.Update()
        update.members = [handle]
        
        // 报告新来电
        Task {
            do {
                try await conversationManager.reportNewIncomingConversation(uuid: uuid, update: update)
                print("[LiveCommunicationKitManager] 来电界面已显示: \(callerName)")
                self.isShowingIncomingCall = true
            } catch {
                print("[LiveCommunicationKitManager] 报告来电失败: \(error.localizedDescription)")
            }
        }
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
    }
    
    /// 标记为已拒绝
    public func markCallRejected() {
        isShowingIncomingCall = false
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
            // 用户点击了接听
            delegate?.liveCommunicationKitDidAcceptCall(uuid: action.uuid)
            action.fulfill()
        } else if action is EndConversationAction {
            // 用户点击了拒绝或结束通话
            if action.state == .running {
                delegate?.liveCommunicationKitDidRejectCall(uuid: action.uuid)
            }
            action.fulfill()
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
