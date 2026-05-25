//
//  CallKitManager.swift
//  AgoraCallKit
//
//  Apple CallKit 集成：支持锁屏/后台来电接听界面
//  收到 VoIP 推送后，通过 CXProvider 向系统报告来电，显示系统来电 UI
//  用户在系统界面上接听/拒绝后，通过 CXProviderDelegate 回调通知 CallManager
//  iOS区不给用，屏蔽了
#if !CHINA_APP_STORE
import Foundation
import CallKit
import AVFoundation

/// CallKit 事件委托，由 CallManager 实现
public protocol CallKitManagerDelegate: AnyObject {
    /// 用户在系统来电界面点击了接听
    func callKitManagerDidAcceptCall()
    /// 用户在系统来电界面点击了拒绝
    func callKitManagerDidRejectCall()
    /// 系统来电界面消失（未接听超时等）
    func callKitManagerDidEndCall()
    /// Provider 被系统重置
    func callKitManagerDidReset()
    /// App 进入前台，CallKit 来电界面已关闭，但用户已在系统界面接听，需要保持通话
    func callKitManagerDidDismissWhileAccepted()
}

/// CallKit 管理器：向系统报告来电、管理通话生命周期
/// 所有方法内部会检查 CallConfiguration.shared.isCallKitEnabled，
/// 若未启用则静默忽略，App 仅通过 uiDelegate 处理来电（默认通知模式）
public class CallKitManager: NSObject {
    
    public static let shared = CallKitManager()
    
    public weak var delegate: CallKitManagerDelegate?
    
    /// CXProvider：向系统报告通话事件
    private var provider: CXProvider?
    /// CXCallController：请求系统执行通话操作
    private let callController = CXCallController()
    
    /// 当前通话的 UUID
    private var currentCallUUID: UUID?
    
    /// 是否正在显示系统来电界面
    public private(set) var isShowingIncomingCall = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - 配置
    
    /// 配置 CallKit Provider
    /// 仅在 CallConfiguration.shared.isCallKitEnabled = true 时生效
    public func configure() {
        guard CallConfiguration.shared.isCallKitEnabled else {
            AgoraLogger.info("CallKit 未启用，跳过配置", module: "CallKitManager")
            return
        }
        
        let iconName = CallConfiguration.shared.callKitIconName
        
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.supportedHandleTypes = [.phoneNumber, .generic]
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        
        if let iconName = iconName {
            configuration.iconTemplateImageData = UIImage(named: iconName)?.pngData()
        }
        
        // 配置来电铃声：
        // 优先级：CallConfiguration.callKitRingtoneSound > CallSoundService.incomingRingtonePath > 系统默认
        if let ringtoneSound = CallConfiguration.shared.callKitRingtoneSound {
            // 显式配置的铃声
            configuration.ringtoneSound = ringtoneSound
            AgoraLogger.info("使用显式配置的铃声: \(ringtoneSound)", module: "CallKitManager")
        } else if let incomingPath = CallSoundService.shared.incomingRingtonePath {
            // 复用 CallSoundService 的来电铃声（从完整路径提取文件名）
            let ringtoneName = (incomingPath as NSString).lastPathComponent
            configuration.ringtoneSound = ringtoneName
            AgoraLogger.info("复用 CallSoundService 铃声: \(ringtoneName)", module: "CallKitManager")
        } else {
            // 使用系统默认铃声
            configuration.ringtoneSound = nil
            AgoraLogger.info("使用系统默认来电铃声", module: "CallKitManager")
        }
        
        let provider = CXProvider(configuration: configuration)
        provider.setDelegate(self, queue: nil)
        self.provider = provider
        
        AgoraLogger.info("已配置 CallKit", module: "CallKitManager")
    }
    
    // MARK: - 报告来电
    
    /// 向系统报告收到来电（收到 VoIP 推送后调用）
    /// 若 CallKit 未启用则静默忽略，App 通过 uiDelegate 处理来电即可
    public func reportIncomingCall(uuid: UUID, handle: String, callerName: String, isVideo: Bool,
                                   completion: @escaping (Bool) -> Void) {
        AgoraLogger.info("reportIncomingCall: uuid=\(uuid)", module: "CallKitManager")
        guard CallConfiguration.shared.isCallKitEnabled else {
            AgoraLogger.info("CallKit 未启用，跳过报告来电", module: "CallKitManager")
            completion(false)
            return
        }
        
        currentCallUUID = uuid
        AgoraLogger.info("reportIncomingCall: currentCallUUID 已设置为 \(uuid)", module: "CallKitManager")
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
//        update.remoteName = callerName
        update.hasVideo = isVideo
        update.supportsDTMF = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        
        provider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                AgoraLogger.info("报告来电失败: \(error.localizedDescription)", module: "CallKitManager")
                self?.currentCallUUID = nil
                completion(false)
            } else {
                AgoraLogger.info("系统来电界面已显示: \(callerName)", module: "CallKitManager")
                self?.isShowingIncomingCall = true
                completion(true)
            }
        }
    }
    
    // MARK: - 报告通话状态变化
    
    /// 报告通话已接通
    public func reportCallConnected() {
        guard CallConfiguration.shared.isCallKitEnabled else { return }
        guard let uuid = currentCallUUID else { return }
        provider?.reportOutgoingCall(with: uuid, connectedAt: Date())
        isShowingIncomingCall = false
    }
    
    /// 报告通话已结束
    public func reportCallEnded(reason: CallEndedReason = .remoteEnded) {
        AgoraLogger.info("reportCallEnded: isCallKitEnabled=\(CallConfiguration.shared.isCallKitEnabled), currentCallUUID=\(currentCallUUID?.uuidString ?? "nil")", module: "CallKitManager")
        guard CallConfiguration.shared.isCallKitEnabled else { return }
        guard let uuid = currentCallUUID else {
            AgoraLogger.info("reportCallEnded: UUID 为空，跳过", module: "CallKitManager")
            return
        }
        AgoraLogger.info("reportCallEnded: uuid=\(uuid), reason=\(reason)", module: "CallKitManager")
        provider?.reportCall(with: uuid, endedAt: Date(), reason: reason.cxCallEndedReason)
        currentCallUUID = nil
        isShowingIncomingCall = false
    }
    
    // MARK: - 主动操作
    
    /// 标记为已接听（当用户在 App 内点击"接受"时调用，通知 CallKit 停止震动）
    public func markCallAccepted() {
        guard CallConfiguration.shared.isCallKitEnabled else { return }
        guard let uuid = currentCallUUID else {
            AgoraLogger.info("markCallAccepted: UUID 为空，跳过", module: "CallKitManager")
            return
        }
        // 通过 CXAnswerCallAction 来标记通话已开始，从而停止 CallKit 的震动
        let action = CXAnswerCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error = error {
                AgoraLogger.info("markCallAccepted 失败: \(error.localizedDescription)", module: "CallKitManager")
            } else {
                AgoraLogger.info("markCallAccepted 成功，CallKit 来电界面应停止震动", module: "CallKitManager")
                self.isShowingIncomingCall = false
            }
        }
    }
    
    /// 关闭来电界面（App 进入前台时调用，隐藏系统来电界面）
    /// - Parameter hasUserAccepted: 用户是否已经在系统界面点击了接听
    public func dismissIncomingCallUI(hasUserAccepted: Bool = false) {
        guard CallConfiguration.shared.isCallKitEnabled else { return }
        guard let uuid = currentCallUUID, isShowingIncomingCall else {
            AgoraLogger.info("dismissIncomingCallUI: 无需关闭（UUID=\(currentCallUUID?.uuidString ?? "nil", default: "CallKitManager"), isShowing=\(isShowingIncomingCall)）", module: "CallKitManager")
            return
        }
        AgoraLogger.info("dismissIncomingCallUI: 关闭系统来电界面, hasUserAccepted=\(hasUserAccepted)", module: "CallKitManager")
        
        if hasUserAccepted {
            // 用户已在系统界面接听，只关闭界面不结束通话
            AgoraLogger.info("dismissIncomingCallUI: 用户已接听，标记为需要保持通话", module: "CallKitManager")
            // 标记为不再显示来电界面
            isShowingIncomingCall = false
            // 通知 delegate 通话需要继续（不调用 hangUp）
            delegate?.callKitManagerDidDismissWhileAccepted()
        } else {
            // 用户还未接听：直接标记为不显示来电界面，由 App 显示来电弹窗
            // 注意：不调用 CXEndCallAction，避免触发 didEndCall → rejectCall
            AgoraLogger.info("dismissIncomingCallUI: 用户未接听，标记隐藏，由 App 显示来电弹窗", module: "CallKitManager")
            isShowingIncomingCall = false
        }
    }
    
    /// 主动结束通话（用户在 App 内点击挂断时调用，通知系统更新 UI）
    public func endCall() {
        guard CallConfiguration.shared.isCallKitEnabled else { return }
        guard let uuid = currentCallUUID else { return }
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error = error {
                AgoraLogger.info("结束通话请求失败: \(error.localizedDescription)", module: "CallKitManager")
            }
        }
    }
    
    /// 请求系统提供通话音频会话（CallKit 管理音频会话时需要激活）
    public func requestAudioSession() {
        // CallKit 会自动管理音频会话的激活
        // 这里可以用于额外的音频配置
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {
    
    /// 系统来电界面点击接听
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        AgoraLogger.info("用户在系统界面点击了接听", module: "CallKitManager")
        action.fulfill()
        isShowingIncomingCall = false
        delegate?.callKitManagerDidAcceptCall()
    }
    
    /// 系统来电界面点击拒绝
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        AgoraLogger.info("用户在系统界面点击了拒绝/结束", module: "CallKitManager")
        action.fulfill()
        isShowingIncomingCall = false
        currentCallUUID = nil
        delegate?.callKitManagerDidEndCall()
    }
    
    /// 用户在系统界面设置了静音
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        action.fulfill()
        // 可扩展：同步静音状态到 CallManager
    }
    
    /// 通话开始（provider 激活音频会话）
    public func providerDidActivate(_ provider: CXProvider, session: AVAudioSession) {
        AgoraLogger.info("音频会话已激活", module: "CallKitManager")
        // CallKit 管理的音频会话已激活，可以开始音频操作
    }
    
    /// 通话结束（provider 停用音频会话）
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        AgoraLogger.info("音频会话已停用", module: "CallKitManager")
    }
    
    /// Provider 被系统重置（必须实现的代理方法）
    public func providerDidReset(_ provider: CXProvider) {
        AgoraLogger.info("Provider 被系统重置", module: "CallKitManager")
        isShowingIncomingCall = false
        currentCallUUID = nil
        delegate?.callKitManagerDidReset()   // 通知 CallManager 强制结束通话
    }
    
    /// 超时未接听
    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        AgoraLogger.info("来电超时未接听", module: "CallKitManager")
        action.fulfill()
        isShowingIncomingCall = false
        currentCallUUID = nil
        delegate?.callKitManagerDidEndCall()
    }
}
#endif
