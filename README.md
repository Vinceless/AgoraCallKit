# AgoraCallKit

基于声网（Agora）RTC SDK 的 iOS 通话组件，提供完整的音视频通话功能，支持单聊和群聊场景。

## 功能特性

- **单聊通话**：一对一音频/视频通话
- **群聊通话**：多人群组音频/视频通话
- **来电管理**：来电弹窗、接听/拒接
- **悬浮窗**：通话中最小化为悬浮窗，支持拖拽和恢复全屏
- **画中画（PiP）**：视频通话退后台自动启用画中画，返回前台自动恢复
- **呼叫超时**：可配置超时时间，超时自动挂断
- **通话计时**：实时显示通话时长
- **音视频控制**：麦克风、摄像头、扬声器（自动初始化/清理）、前后镜头切换
- **远端状态同步**：远端用户静音/关闭摄像头状态实时更新
- **状态机管理**：完整的通话生命周期状态管理
- **系统来电界面**：支持 CallKit（iOS 10+）和 LiveCommunicationKit（iOS 17.4+）
- **VoIP 推送**：支持 VoIP 推送触发的来电显示
- **信令重试**：指数退避重试发送失败的信令，保障信令可靠性
- **统一日志**：内置模块化日志系统，支持级别过滤、自定义输出目标

## 项目结构

```
Sources/
├── AgoraEngineManager.swift           # 声网引擎封装
├── CallManager.swift                  # 通话核心管理器
├── Model/
│   ├── AgoraLogger.swift              # 统一日志管理器
│   ├── CallConfiguration.swift        # 通话配置项
│   ├── CallError.swift                # 错误类型定义
│   ├── CallSession.swift              # 通话会话模型
│   ├── CallSoundService.swift         # 通话音效服务
│   ├── CallState.swift                # 通话状态枚举
│   ├── CallType.swift                 # 通话类型/模式枚举
│   ├── CallUser.swift                 # 用户信息模型
│   ├── CallKitManager.swift           # CallKit 管理器
│   ├── IncomingCallManager.swift      # 来电弹窗管理器
│   ├── LiveCommunicationKitManager.swift  # LiveCommunicationKit 管理器
│   ├── PictureInPictureManager.swift  # 画中画管理器
│   ├── SignalRetryManager.swift       # 信令重试管理器
│   ├── UIWindowScene+KeyWindow.swift  # KeyWindow 工具扩展
│   ├── VideoRendererBinder.swift      # 视频渲染绑定器
│   └── VoIPPushManager.swift          # VoIP 推送管理器
├── Protocols/
│   ├── AgoraEngineProtocol.swift          # 引擎抽象协议
│   ├── CallSignalDelegate.swift           # 信令收发协议
│   ├── CallSoundServiceProtocol.swift     # 音效服务协议
│   ├── CallUIDelegate.swift               # UI 回调协议
│   ├── CallUIDelegateMulticast.swift      # UI 多播代理
│   ├── CurrentUserProvider.swift          # 当前用户信息协议
│   ├── PIPVideoFrameDelegate.swift        # PiP 视频帧代理
│   └── TokenProvider.swift                # Token 获取协议
└── UI/
    ├── BaseCallViewController.swift            # 通话界面基类
    ├── BaseIncomingCallView.swift              # 来电弹窗基类
    ├── FloatingWindow.swift                    # 悬浮窗组件
    ├── SingleAudioCallViewController.swift     # 单聊音频界面
    ├── SingleVideoCallViewController.swift     # 单聊视频界面
    ├── GroupAudioCallViewController.swift      # 群聊音频界面
    └── GroupVideoCallViewController.swift      # 群聊视频界面
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

## 日志系统（AgoraLogger）

框架内置统一日志管理器，所有模块日志集中输出，支持级别过滤和自定义输出。

### 日志级别

| 级别 | 枚举值 | 说明 |
|------|--------|------|
| `debug` | `AgoraLogLevel.debug` | 调试信息，DEVELOP 环境默认输出 |
| `info` | `AgoraLogLevel.info` | 一般信息 |
| `warning` | `AgoraLogLevel.warning` | 警告信息 |
| `error` | `AgoraLogLevel.error` | 错误信息 |
| `none` | `AgoraLogLevel.none` | 关闭所有日志 |

### 日志配置

```swift
// 设置最低日志级别（低于此级别不输出）
// DEBUG 模式默认 .debug，RELEASE 模式默认 .warning
AgoraLogger.shared.minimumLevel = .warning  // 仅输出警告和错误

// 完全关闭日志
AgoraLogger.shared.minimumLevel = .none

// 自定义输出目标（如写入文件、上传到服务端）
AgoraLogger.shared.output = { formattedLog in
    // 将日志写入文件
    yourFileLogger.append(formattedLog)
}
```

### 在自定义代码中使用

```swift
// 推荐方式：直接使用静态方法
AgoraLogger.debug("调试信息", module: "MyModule")
AgoraLogger.info("用户 \(userId) 发起通话", module: "MyModule")
AgoraLogger.warning("Token 即将过期", module: "MyModule")
AgoraLogger.error("加入频道失败: \(error)", module: "MyModule")
```

### 内置模块标识

框架内部使用以下模块标识，便于按模块过滤日志：

| 模块标识 | 对应文件 |
|----------|----------|
| `CallManager` | CallManager.swift |
| `AgoraEngineManager` | AgoraEngineManager.swift |
| `LiveCommunicationKit` | LiveCommunicationKitManager.swift |
| `CallKitManager` | CallKitManager.swift |
| `PiP` | PictureInPictureManager.swift |
| `CallSoundService` | CallSoundService.swift |
| `VoIPPushManager` | VoIPPushManager.swift |
| `SignalRetryManager` | SignalRetryManager.swift |
| `SingleVideo` | SingleVideoCallViewController.swift |

## 信令重试（SignalRetryManager）

对于网络波动导致的信令（挂断/接听/拒绝/取消）发送失败，框架内置指数退避重试机制。

### 重试策略

```swift
let policy = SignalRetryManager.RetryPolicy(
    maxRetries: 3,          // 最大重试 3 次
    initialDelay: 1.0,      // 初始延迟 1 秒
    multiplier: 2.0,        // 每次延迟翻倍（1s → 2s → 4s）
    maxDelay: 10.0          // 最大延迟 10 秒
)
```

### 使用方式

```swift
// 重试管理器已集成在 CallManager 内部，无需单独调用

// 如果需要自定义重试策略：
SignalRetryManager.shared.defaultPolicy = SignalRetryManager.RetryPolicy(
    maxRetries: 5,
    initialDelay: 0.5,
    multiplier: 1.5,
    maxDelay: 5.0
)
```

## 系统来电界面配置

### CallKit 和 LiveCommunicationKit 概述

| 框架 | iOS 版本 | 说明 |
|------|---------|------|
| CallKit | 10.0+ | 系统来电界面，支持锁屏/后台接听 |
| LiveCommunicationKit | 17.4+ | 新一代 VoIP 来电框架，支持后台唤醒，同样支持锁屏/后台接听，可规避 CallKit 审核风险 |

### 配置逻辑矩阵

| isLiveCommunicationKitEnabled | isCallKitEnabled | iOS 版本 | 结果 |
|------------------------------|------------------|---------|------|
| `true` | 任意 | 17.4+ | **LiveCommunicationKit** |
| `true` | `true` | < 17.4 | CallKit（回退） |
| `true` | `false` | < 17.4 | 不使用系统来电界面 |
| `false` | `true` | 任意 | CallKit |
| `false` | `false` | 任意 | 不使用系统来电界面 |

> **中国区注意**: 定义了 `CHINA_APP_STORE` 编译标记后，`isCallKitEnabled` 始终为 `false`，此时应使用 `.liveCommunicationKitOnly` 或 `.voipPushOnly` 模式。详见下方 [中国区 App Store 适配](#中国区-app-store-适配china_app_store) 章节。

### 基础配置示例

```swift
// ========== 方式一：使用高级 API（推荐）==========

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

// ========== 方式二：链式调用 ==========
CallConfiguration.shared
    .configure(mode: .auto)
    .callKitRingtoneSound = "ringtone_call.caf"

// ========== 方式三：快速配置 ==========
CallConfiguration.shared.enableForVoIPPushOnly()
```

### VoIP 推送集成示例

当使用 VoIP 推送触发的来电时，在收到推送时配置系统来电界面：

```swift
// AppDelegate 或初始化时配置
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 配置通话功能
        CallSoundService.shared.isSoundEnabled = true
        CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
        
        // 注册 VoIP 推送
        VoIPPushManager.shared.payloadDelegate = self
        VoIPPushManager.shared.registerForVoIPPush()
        
        return true
    }
}

// 实现 VoIPPushPayloadDelegate
extension AppDelegate: VoIPPushPayloadDelegate {
    func voipPushManager(didReceivePayload payload: [AnyHashable: Any], completion: @escaping (CallIncomingInfo?) -> Void) {
        // 收到 VoIP 推送时，获取系统来电界面展示类型
        let displayType = CallConfiguration.shared.displayType(for: .voIPPush)
        
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
        
        // 仅在 VoIP 推送时启用系统来电界面（推荐）
        CallConfiguration.shared.configure(mode: .voipPushOnly)
        
        // 其他配置方式：
        // - .none: 仅使用 App 内弹窗
        // - .callKitOnly: 仅使用 CallKit
        // - .liveCommunicationKitOnly: 仅使用 LiveCommunicationKit（iOS 17.4+）
        // - .auto: 优先 LiveCommunicationKit，iOS < 17.4 回退到 CallKit
        
        // 可选：自定义系统来电界面铃声
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
        // 普通来电不使用系统来电界面
        let displayType = CallConfiguration.shared.displayType(for: .normal)
        
        CallManager.shared.receiveIncomingCall(
            from: user,
            channelName: channelName,
            token: token,
            callType: callType
        )
    }
    
    /// 处理 WebSocket 信令的来电（仅 VoIP 推送触发时使用系统来电界面）
    func handleIncomingCallFromVoIP(from user: CallUser, channelName: String, token: String, callType: CallType) {
        // VoIP 推送触发的来电使用系统来电界面
        let displayType = CallConfiguration.shared.displayType(for: .voIPPush)
        
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
            // 通话结束，重置系统来电界面配置
            CallConfiguration.shared.configure(mode: .none)
            // 清除 VoIP 推送状态
            VoIPPushManager.shared.clearLastPayload()
        default:
            break
        }
    }
}
```

## 中国区 App Store 适配（CHINA_APP_STORE）

由于 CallKit 在中国大陆地区受到限制，框架通过 `CHINA_APP_STORE` 编译标记来区分中国区和全球区版本。**全球区版本默认包含 CallKit 支持，中国区版本编译时排除所有 CallKit 相关代码。**

### 行为差异

| 编译标记 | CallKit | LiveCommunicationKit | 推荐 mode |
|----------|---------|---------------------|------------|
| **未定义**（全球区） | ✅ 可用 | ✅ 可用（iOS 17.4+） | `.auto`（默认） |
| **定义了 CHINA_APP_STORE**（中国区） | ❌ 不可用 | ✅ 可用（iOS 17.4+） | `.liveCommunicationKitOnly` |

> **注意**: LiveCommunicationKit 是目前 iOS 17.4+ 在中国区可用的系统来电框架，可用于替代 CallKit 实现锁屏/后台接听能力。

### 集成方式一：Xcode 工程设置

在 Xcode 中为 **中国区 Target** 添加编译标记：

1. 选中项目 → 选择中国区 Target → **Build Settings**
2. 搜索 **Swift Compiler - Custom Flags**
3. 在 **Active Compilation Conditions** 中添加：

```
CHINA_APP_STORE
```

4. 确保该标记**仅**在中国区 Target 中设置，**全球区 Target 不添加**

### 集成方式二：CocoaPods（podspec）

通过 `pod_target_xcconfig` 按 Target 注入编译标记：

```ruby
# 方式 A：在工程 Podfile 中按 Target 设置
target 'YourApp_China' do
  pod 'AgoraCallKit'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == 'AgoraCallKit'
      # 仅为中国区 Target 添加编译标记
      target.build_configurations.each do |config|
        config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['$(inherited)']
        config.build_settings['OTHER_SWIFT_FLAGS'] << '-D CHINA_APP_STORE'
      end
    end
  end
end
```

```ruby
# 方式 B：直接修改 podspec（不推荐，影响所有集成方）
spec.pod_target_xcconfig = {
  'OTHER_SWIFT_FLAGS' => '-D CHINA_APP_STORE'
}
```

### 集成方式三：Swift Package Manager (SPM)

在 `Package.swift` 中通过 Target 的 `swiftSettings` 添加：

```swift
.target(
    name: "AgoraCallKit",
    dependencies: [...],
    path: "Sources",
    swiftSettings: [
        // 中国区版本取消注释下面这行
        // .define("CHINA_APP_STORE"),
    ]
)
```

> SPM 方式下，建议维护两个分支或通过 CI 切换标记。

### 中国区推荐配置

当定义了 `CHINA_APP_STORE` 后，CallKit 代码在编译时即被排除，CallConfiguration 中应使用 **LiveCommunicationKit** 作为系统来电界面：

```swift
// 中国区 App Store 版本
CallConfiguration.shared.configure(mode: .liveCommunicationKitOnly)
// 或：仅在 VoIP 推送时显示系统来电界面
CallConfiguration.shared.configure(mode: .voipPushOnly)
```

### 全球区推荐配置

全球区版本不定义 `CHINA_APP_STORE`，CallKit 和 LiveCommunicationKit 均可使用：

```swift
// 全球 App Store 版本
CallConfiguration.shared.configure(mode: .auto)
// .auto 模式会自动选择：
//   iOS 17.4+ → LiveCommunicationKit
//   iOS < 17.4 → CallKit
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
