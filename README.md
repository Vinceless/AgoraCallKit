# AgoraCallKit

基于声网（Agora）RTC SDK 的 iOS 通话组件，提供完整的音视频通话功能，支持单聊和群聊场景。

## 功能特性

- **单聊通话**：一对一音频/视频通话
- **群聊通话**：多人群组音频/视频通话
- **来电管理**：来电弹窗、接听/拒接
- **悬浮窗**：通话中最小化为悬浮窗，支持拖拽和恢复全屏
- **画中画（PiP）**：视频通话退后台自动启用画中画
- **呼叫超时**：可配置超时时间，超时自动挂断
- **通话计时**：实时显示通话时长
- **音视频控制**：麦克风、摄像头、扬声器、前后镜头切换
- **远端状态同步**：远端用户静音/关闭摄像头状态实时更新
- **状态机管理**：完整的通话生命周期状态管理
- **系统来电界面**：支持 CallKit（iOS 10+）和 LiveCommunicationKit（iOS 17.4+）
- **VoIP 推送**：支持 VoIP 推送触发的来电显示

## 项目结构

```
Sources/
├── AgoraEngineManager.swift        # 声网引擎封装
├── CallManager.swift               # 通话核心管理器
├── Model/
│   ├── CallState.swift             # 通话状态枚举
│   ├── CallType.swift              # 通话类型/模式枚举
│   ├── CallUser.swift              # 用户信息模型
│   ├── CallConfiguration.swift     # 通话配置项
│   ├── CallKitManager.swift        # CallKit 管理器
│   ├── LiveCommunicationKitManager.swift  # LiveCommunicationKit 管理器
│   ├── IncomingCallManager.swift   # 来电弹窗管理器
│   ├── CallSoundService.swift      # 通话音效服务
│   ├── VoIPPushManager.swift       # VoIP 推送管理器
│   └── PictureInPictureManager.swift # 画中画管理器
├── Protocols/
│   ├── CallSignalDelegate.swift    # 信令收发协议
│   ├── CallUIDelegate.swift        # UI 回调协议
│   ├── CurrentUserProvider.swift   # 当前用户信息协议
│   ├── TokenProvider.swift         # Token 获取协议
│   └── PIPVideoFrameDelegate.swift # PiP 视频帧代理
└── UI/
    ├── BaseCallViewController.swift      # 通话界面基类
    ├── BaseIncomingCallView.swift        # 来电弹窗基类
    ├── SingleAudioCallViewController.swift  # 单聊音频界面
    ├── SingleVideoCallViewController.swift  # 单聊视频界面
    ├── GroupAudioCallViewController.swift   # 群聊音频界面
    ├── GroupVideoCallViewController.swift   # 群聊视频界面
    └── FloatingWindow.swift               # 悬浮窗组件
```

## 快速开始

### 1. 初始化

在 App 启动时配置声网引擎和信令：

```swift
// 配置声网引擎
AgoraEngineManager.shared.configure(appId: "your-agora-app-id")

// 设置信令代理（实现 CallSignalDelegate 协议）
CallManager.shared.signalDelegate = YourSignalService()

// 设置 Token 提供者（实现 TokenProvider 协议）
CallManager.shared.tokenProvider = YourTokenService()

// 设置当前用户信息（实现 CurrentUserProvider 协议）
CallManager.shared.userProvider = YourUserService()

// 设置 UI 代理以接收通话状态回调
CallManager.shared.uiDelegate.add(YourUIDelegate())
```

### 2. 发起通话

```swift
let remoteUser = CallUser(uid: 1234, name: "张三", avatar: "https://...")
CallManager.shared.startCall(
    to: remoteUser,
    channelName: "channel_1234_5678",
    callType: .video
) { result in
    switch result {
    case .success: print("发起成功")
    case .failure(let error): print("发起失败: \(error)")
    }
}
```

### 3. 接听/拒绝来电

实现 `CallUIDelegate.didReceiveIncomingCall` 接收来电通知：

```swift
func didReceiveIncomingCall(from user: CallUser, callType: CallType, channelName: String, token: String) {
    // 展示来电界面
    let incomingView = BaseIncomingCallView()
    incomingView.configure(with: user, callType: callType)
    IncomingCallManager.shared.show(incomingView)
}

// 接听
CallManager.shared.acceptCall()

// 拒绝
CallManager.shared.rejectCall()
```

### 4. 挂断通话

```swift
CallManager.shared.hangUp()
```

### 5. 使用内置通话界面

```swift
// 单聊视频
let vc = SingleVideoCallViewController()
present(vc, animated: true)

// 单聊音频
let vc = SingleAudioCallViewController()
present(vc, animated: true)

// 群聊视频
let vc = GroupVideoCallViewController()
present(vc, animated: true)

// 群聊音频
let vc = GroupAudioCallViewController()
present(vc, animated: true)
```

## 通话状态流转

```
idle ──→ calling ──→ connecting ──→ connected ──→ disconnected ──→ idle
  │                                          │
  └──→ incoming ──→ connecting ──→ connected──┤
                                              └──→ reconnecting ──→ connected

任意活跃状态 → failed → idle
```

| 状态 | 说明 |
:|------|------|
| `idle` | 空闲，无通话 |
| `calling` | 主叫等待对方接听 |
| `incoming` | 被叫收到来电 |
| `connecting` | 加入频道中 |
| `connected` | 通话已接通 |
| `reconnecting` | 网络断开重连中 |
| `disconnected` | 通话正常结束 |
| `failed` | 通话失败 |

## 核心协议

### CallSignalDelegate（信令协议）

App 层需实现此协议，负责与信令服务器通信：

| 方法 | 说明 |
|------|------|
| `sendCallRequest(toUserId:channelName:token:callType:completion:)` | 发起通话请求 |
| `sendAcceptResponse(toUserId:completion:)` | 发送接听响应 |
| `sendRejectResponse(toUserId:reason:completion:)` | 发送拒绝响应 |
| `sendHangupSignal(toUserId:completion:)` | 发送挂断信令 |
| `sendCancelSignal(toUserId:completion:)` | 发送取消通话信令 |
| `setListener(_:)` | 注册信令监听器 |

### CallUIDelegate（UI 回调协议）

所有方法均有默认空实现，按需重写：

| 方法 | 说明 |
|------|------|
| `callStateDidChange(_:)` | 通话状态变化 |
| `didJoinChannel(withUser:)` | 本地加入频道 |
| `didDisconnect(error:)` | 通话断开 |
| `remoteUserDidJoin(_:)` | 远端用户加入 |
| `remoteUserDidLeave(_:)` | 远端用户离开 |
| `didUpdateDuration(_:)` | 通话时长更新（每秒） |
| `didReceiveIncomingCall(from:callType:channelName:token:)` | 收到来电 |
| `didOccurError(_:)` | 发生错误 |
| `remoteUserDidToggleVideo(_:muted:)` | 远端视频静音变化 |
| `remoteUserDidToggleAudio(_:muted:)` | 远端音频静音变化 |
| `localAudioMutedDidChange(_:)` | 本地音频静音变化 |
| `localVideoMutedDidChange(_:)` | 本地视频静音变化 |

### TokenProvider & CurrentUserProvider

```swift
// Token 提供者
class YourTokenService: TokenProvider {
    func fetchToken(channelName: String, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 从你的服务器获取 Agora Token
        yourAPI.fetchToken(channel: channelName, uid: userId) { result in
            completion(result)
        }
    }
}

// 用户信息提供者
class YourUserService: CurrentUserProvider {
    var currentUserId: String { "1234" }
    var currentUserName: String { "当前用户昵称" }
}
```

## 系统来电界面配置

### CallKit 和 LiveCommunicationKit 概述

| 框架 | iOS 版本 | 说明 |
|------|---------|------|
| CallKit | 10.0+ | 系统来电界面，支持锁屏/后台接听 |
| LiveCommunicationKit | 17.4+ | 新一代 VoIP 来电框架，可规避 CallKit 审核风险 |

### 配置逻辑矩阵

| isLiveCommunicationKitEnabled | isCallKitEnabled | iOS 版本 | 结果 |
|------------------------------|------------------|---------|------|
| `true` | 任意 | 17.4+ | **LiveCommunicationKit** |
| `true` | `true` | < 17.4 | CallKit（回退） |
| `true` | `false` | < 17.4 | 不使用系统来电界面 |
| `false` | `true` | 任意 | CallKit |
| `false` | `false` | 任意 | 不使用系统来电界面 |

### 基础配置示例

```swift
// 方式一：默认不使用系统来电界面（仅使用 App 内弹窗）
CallConfiguration.shared.isCallKitEnabled = false

// 方式二：启用 CallKit（所有 iOS 版本使用）
CallConfiguration.shared.isCallKitEnabled = true
CallConfiguration.shared.isLiveCommunicationKitEnabled = false

// 方式三：启用 LiveCommunicationKit（iOS 17.4+ 使用，规避审核风险）
CallConfiguration.shared.isCallKitEnabled = true
CallConfiguration.shared.isLiveCommunicationKitEnabled = true
```

### VoIP 推送集成示例

当使用 VoIP 推送触发的来电时，可以动态控制是否启用系统来电界面：

```swift
// AppDelegate 或初始化时配置
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 配置通话功能
        CallSoundService.shared.isSoundEnabled = true
        CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
        
        // 默认禁用系统来电界面
        CallConfiguration.shared.isCallKitEnabled = false
        
        // 注册 VoIP 推送
        VoIPPushManager.shared.payloadDelegate = self
        VoIPPushManager.shared.registerForVoIPPush()
        
        return true
    }
}

// 实现 VoIPPushPayloadDelegate
extension AppDelegate: VoIPPushPayloadDelegate {
    func voipPushManager(didReceivePayload payload: [AnyHashable: Any], completion: @escaping (CallIncomingInfo?) -> Void) {
        // 收到 VoIP 推送时，启用系统来电界面
        CallConfiguration.shared.isCallKitEnabled = true
        
        // 解析推送内容
        let fromUserId = payload["fromUserId"] as? String ?? ""
        let channelName = payload["channelName"] as? String ?? ""
        let token = payload["token"] as? String ?? ""
        let callTypeStr = payload["callType"] as? String ?? "voice"
        let callerName = payload["callerName"] as? String ?? fromUserId
        
        let callType: CallType = (callTypeStr == "video") ? .video : .voice
        
        let info = CallIncomingInfo(
            fromUserId: fromUserId,
            channelName: channelName,
            token: token,
            callType: callType,
            callerName: callerName,
            callerAvatar: payload["callerAvatar"] as? String ?? ""
        )
        completion(info)
    }
}
```

### 完整配置示例

```swift
class CallServiceManager {
    static let shared = CallServiceManager()
    
    private init() {
        // 配置声网引擎
        AgoraEngineManager.shared.configure(appId: "your-agora-app-id")
        
        // 配置音效
        CallSoundService.shared.isSoundEnabled = true
        CallSoundService.shared.outgoingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
        CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
        
        // ============ 系统来电界面配置 ============
        
        // 方式一：仅使用 App 内弹窗（不启用系统来电界面）
        CallConfiguration.shared.isCallKitEnabled = false
        
        // 方式二：启用 CallKit（所有 iOS 版本）
        // CallConfiguration.shared.isCallKitEnabled = true
        // CallConfiguration.shared.isLiveCommunicationKitEnabled = false
        
        // 方式三：启用 LiveCommunicationKit（iOS 17.4+ 推荐，规避审核风险）
        // CallConfiguration.shared.isCallKitEnabled = true
        // CallConfiguration.shared.isLiveCommunicationKitEnabled = true
        
        // 可选：自定义系统来电界面铃声（复用 CallSoundService）
        // 铃声优先级：CallConfiguration.callKitRingtoneSound > CallSoundService.incomingRingtonePath > 系统默认
        // CallConfiguration.shared.callKitRingtoneSound = "custom_ringtone.caf"
        
        // 可选：设置系统来电界面角标图标
        // CallConfiguration.shared.callKitIconName = "AppIcon"
        
        // ============ 依赖注入 ============
        
        CallManager.shared.signalDelegate = YourSignalService()
        CallManager.shared.tokenProvider = YourTokenService()
        CallManager.shared.userProvider = YourUserService()
        CallManager.shared.uiDelegate.add(AppCallUIDelegate())
        
        // 注册 VoIP 推送（收到推送时自动启用系统来电界面）
        VoIPPushManager.shared.payloadDelegate = self
        VoIPPushManager.shared.registerForVoIPPush()
    }
}
```

### WebSocket 信令处理示例

当通过 WebSocket 信令收到来电时，通常不希望使用系统来电界面：

```swift
class CallServiceManager {
    
    /// 处理 WebSocket 信令的来电（不使用系统来电界面）
    func handleIncomingCall(from user: CallUser, channelName: String, token: String, callType: CallType) {
        // 确保非 VoIP 推送来电不使用系统来电界面
        CallConfiguration.shared.isCallKitEnabled = false
        
        CallManager.shared.receiveIncomingCall(
            from: user,
            channelName: channelName,
            token: token,
            callType: callType
        )
    }
    
    /// 处理 WebSocket 信令的来电（仅 VoIP 推送触发时使用系统来电界面）
    func handleIncomingCallFromVoIP(from user: CallUser, channelName: String, token: String, callType: CallType) {
        // 仅在 VoIP 推送触发时启用系统来电界面
        CallConfiguration.shared.isCallKitEnabled = true
        
        CallManager.shared.receiveIncomingCall(
            from: user,
            channelName: channelName,
            token: token,
            callType: callType
        )
    }
}
```

### 通话结束后重置状态

通话结束后，需要重置系统来电界面状态：

```swift
class AppCallUIDelegate: NSObject, CallUIDelegate {
    
    func callStateDidChange(_ state: CallState) {
        switch state {
        case .disconnected, .failed, .idle:
            // 通话结束，重置 CallKit 状态
            CallConfiguration.shared.isCallKitEnabled = false
            // 如果使用 VoIP 推送模式，也要重置
            VoIPPushManager.shared.clearLastPayload()
        default:
            break
        }
    }
}
```

## 铃声配置

### 铃声文件要求

- 铃声文件需添加到 App Bundle，不可放在 Assets.xcassets
- 支持格式：Core Audio 支持的格式（.caf, .aiff, .wav, .mp3 等）
- 建议铃声时长 1-30 秒

### 铃声配置优先级

```
CallConfiguration.callKitRingtoneSound > CallSoundService.incomingRingtonePath > 系统默认
```

### 铃声配置示例

```swift
// 方式一：设置 CallSoundService（App 内来电彩铃 + 系统来电界面铃声）
CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")

// 方式二：单独设置系统来电界面铃声
CallConfiguration.shared.callKitRingtoneSound = "custom_ring.caf"

// 方式三：使用 LiveCommunicationKit 时设置铃声
// LiveCommunicationKit 通过 CallConfiguration.callKitRingtoneSound 或 CallSoundService 配置
```

## 自定义

### 自定义来电弹窗

继承 `BaseIncomingCallView`：

```swift
class CustomIncomingCallView: BaseIncomingCallView {
    override func setupUI() {
        super.setupUI()
        // 自定义样式
    }
    
    override func loadAvatar(from url: URL) {
        // 使用你的图片加载库加载头像
        YourImageLoader.load(url, into: avatarImageView)
    }
}
```

### 自定义通话界面

继承 `BaseCallViewController` 或其子类：

```swift
class CustomVideoCallVC: SingleVideoCallViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 自定义 UI 和交互
    }
}
```

## 依赖

- iOS 13.0+（LiveCommunicationKit 需要 iOS 17.4+）
- Swift 5.0+
- Agora RTC SDK（通过 CocoaPods/SPM 集成）
- AVKit（画中画功能，iOS 15.0+）
