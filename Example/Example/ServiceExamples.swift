//
//  ServiceExamples.swift
//  Example
//
//  通话服务初始化和配置示例
//

import Foundation
import UIKit
import AgoraCallKit

// MARK: - 示例服务实现

/// 示例信令服务
class ExampleSignalService: NSObject, CallSignalDelegate {
    
    func sendCallRequest(toUserId: String, channelName: String, token: String, callType: CallType, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: 通过 WebSocket 发送通话请求
        print("[信令] 发送通话请求给 \(toUserId)")
        completion(.success(()))
    }
    
    func sendAcceptResponse(toUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: 通过 WebSocket 发送接听响应
        print("[信令] 发送接听响应给 \(toUserId)")
        completion(.success(()))
    }
    
    func sendRejectResponse(toUserId: String, reason: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: 通过 WebSocket 发送拒绝响应
        print("[信令] 发送拒绝响应给 \(toUserId), reason: \(reason ?? "nil")")
        completion(.success(()))
    }
    
    func sendHangupSignal(toUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: 通过 WebSocket 发送挂断信令
        print("[信令] 发送挂断信令给 \(toUserId)")
        completion(.success(()))
    }
    
    func sendCancelSignal(toUserId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: 通过 WebSocket 发送取消信令
        print("[信令] 发送取消信令给 \(toUserId)")
        completion(.success(()))
    }
    
    func setListener(_ listener: CallSignalListener) {
        // TODO: 设置信令监听器，用于接收对方发来的信令
        // WebSocket 收到信令后调用 listener 的对应方法
        print("[信令] 监听器已设置")
    }
    
    // MARK: - 未接来电查询（可选）
    
    func fetchPendingPrivateCalls(completion: @escaping ([CallInviteMessage]) -> Void) {
        // TODO: 从服务器获取未结束的通话记录
        print("[信令] 查询未接来电")
        completion([])
    }
}

/// 示例 Token 服务
class ExampleTokenService: NSObject, TokenProvider {
    
    func fetchToken(channelName: String, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // TODO: 从你的服务器获取 Agora Token
        // let api = YourAPI()
        // api.getToken(channel: channelName, uid: userId) { result in
        //     completion(result)
        // }
        
        // 示例：直接返回空 Token（仅用于测试）
        print("[Token] 获取 Token: channel=\(channelName), userId=\(userId)")
        completion(.success(""))
    }
}

/// 示例用户服务
class ExampleUserService: NSObject, CurrentUserProvider {
    
    var currentUserId: String? {
        // TODO: 返回当前登录用户的 ID
        return "user_12345"
    }
    
    var currentUserName: String? {
        // TODO: 返回当前登录用户的昵称
        return "测试用户"
    }
}

// MARK: - 通话服务管理器示例

/// 通话服务管理器示例
class ExampleCallServiceManager {
    
    static let shared = ExampleCallServiceManager()
    
    /// 单例私有化
    private init() {}
    
    /// 初始化通话服务
    /// - Parameter mode: 系统来电界面配置模式
    func setup(mode: SystemCallUI = .voipPushOnly) {
        // ========== 1. 配置声网引擎 ==========
        AgoraEngineManager.shared.configure(appId: "your-agora-app-id")
        print("[初始化] 声网引擎配置完成")
        
        // ========== 2. 配置音效 ==========
        CallSoundService.shared.isSoundEnabled = true
        CallSoundService.shared.outgoingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
        CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
        print("[初始化] 音效配置完成")
        
        // ========== 3. 配置系统来电界面 ==========
        CallConfigurationExamples.configure(mode: mode)
        
        // 可选：配置铃声
        // CallConfigurationExamples.configureRingtone("custom_ringtone.caf")
        
        // 可选：配置图标
        // CallConfigurationExamples.configureIcon("AppIcon")
        
        // ========== 4. 注入依赖 ==========
        CallManager.shared.signalDelegate = ExampleSignalService()
        CallManager.shared.tokenProvider = ExampleTokenService()
        CallManager.shared.userProvider = ExampleUserService()
        CallManager.shared.uiDelegate.add(ExampleAppCallUIDelegate())
        print("[初始化] 依赖注入完成")
        
        // ========== 5. 注册 VoIP 推送（如果使用 VoIP 推送模式） ==========
        if mode == .voipPushOnly {
            VoIPPushExamples.register()
        }
        
        // ========== 6. 打印当前配置 ==========
        CallConfigurationExamples.printCurrentConfiguration()
        
        print("[初始化] 通话服务配置完成 ✓")
    }
    
    /// 发起单聊视频通话
    func startVideoCall(to userId: String, userName: String, from presentingVC: UIViewController) {
        let remoteUser = CallUser(
            userId: userId,
            uid: UInt(userId) ?? 0,
            name: userName
        )
        let channelName = "\(ExampleUserService().currentUserId ?? "")-\(userId)"
        
        CallManager.shared.startCall(to: remoteUser, channelName: channelName, callType: .video) { result in
            switch result {
            case .success:
                let callVC = SingleVideoCallViewController()
                callVC.modalPresentationStyle = .fullScreen
                presentingVC.present(callVC, animated: true)
                print("[通话] 视频通话已发起")
            case .failure(let error):
                print("[通话] 发起失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 发起单聊音频通话
    func startAudioCall(to userId: String, userName: String, from presentingVC: UIViewController) {
        let remoteUser = CallUser(
            userId: userId,
            uid: UInt(userId) ?? 0,
            name: userName
        )
        let channelName = "\(ExampleUserService().currentUserId ?? "")-\(userId)"
        
        CallManager.shared.startCall(to: remoteUser, channelName: channelName, callType: .voice) { result in
            switch result {
            case .success:
                let callVC = SingleAudioCallViewController()
                callVC.modalPresentationStyle = .fullScreen
                presentingVC.present(callVC, animated: true)
                print("[通话] 音频通话已发起")
            case .failure(let error):
                print("[通话] 发起失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UI 代理示例

/// App 层通话 UI 代理示例
class ExampleAppCallUIDelegate: NSObject, CallUIDelegate {
    
    func callStateDidChange(_ state: CallState) {
        print("[UI Delegate] 状态变化: \(state)")
        
        switch state {
        case .disconnected, .failed, .idle:
            // 通话结束，重置状态
            CallStateResetExamples.resetAfterCall()
        default:
            break
        }
    }
    
    func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {
        print("[UI Delegate] 收到来电: \(user.name), type=\(callType)")
        
        // 展示来电弹窗
        let incomingView = BaseIncomingCallView()
        incomingView.configure(with: user, callType: callType)
        incomingView.delegate = self
        IncomingCallManager.shared.show(incomingView)
    }
    
    func didDisconnect(error: Error?) {
        print("[UI Delegate] 通话断开: \(error?.localizedDescription ?? "正常挂断")")
        IncomingCallManager.shared.hide()
    }
    
    func didOccurError(_ error: Error) {
        print("[UI Delegate] 发生错误: \(error.localizedDescription)")
    }
}

// MARK: - IncomingCallViewDelegate

extension ExampleAppCallUIDelegate: IncomingCallViewDelegate {
    
    func incomingCallViewDidAccept(_ view: BaseIncomingCallView) {
        IncomingCallManager.shared.hide()
        CallManager.shared.acceptCall()
        // 注意：didAcceptIncomingCall 回调会在 acceptCall 成功内部调用 present
    }
    
    func incomingCallViewDidReject(_ view: BaseIncomingCallView) {
        IncomingCallManager.shared.hide()
        CallManager.shared.rejectCall()
    }
    
    func incomingCallViewDidTap(_ view: BaseIncomingCallView) {
        // 点击来电弹窗，跳转到通话界面（不接听，显示等待界面）
        IncomingCallManager.shared.hide()
        
        if let topVC = UIApplication.shared.visibleViewController {
            let callType = CallManager.shared.getCurrentCallType ?? .voice
            let callVC: BaseCallViewController = callType == .video ? SingleVideoCallViewController() : SingleAudioCallViewController()
            callVC.modalPresentationStyle = .fullScreen
            topVC.present(callVC, animated: true)
        }
    }
}

// MARK: - 新增的来电处理方法

extension ExampleAppCallUIDelegate {
    
    /// App 进入前台时，系统来电界面已关闭，需要展示自定义来电界面
    func didShowIncomingCallUIAfterForeground(from user: CallUser, callType: CallType, channelName: String, token: String) {
        print("[UI Delegate] App 进入前台，显示自定义来电界面: \(user.name)")
        
        // 隐藏可能存在的通话界面
        IncomingCallManager.shared.hide()
        
        // 展示来电弹窗
        let incomingView = BaseIncomingCallView()
        incomingView.configure(with: user, callType: callType)
        incomingView.delegate = self
        IncomingCallManager.shared.show(incomingView)
    }
    
    /// 用户点击了接听，需要 present 通话控制器
    func didAcceptIncomingCall(from user: CallUser, callType: CallType) {
        print("[UI Delegate] 接听来电 present 控制器: \(user.name), type=\(callType)")
        
        // 隐藏来电弹窗
        IncomingCallManager.shared.hide()
        
        // present 通话界面
        if let topVC = UIApplication.shared.visibleViewController {
            let callVC: BaseCallViewController = callType == .video ? SingleVideoCallViewController() : SingleAudioCallViewController()
            callVC.modalPresentationStyle = .fullScreen
            topVC.present(callVC, animated: true)
        }
    }
}
