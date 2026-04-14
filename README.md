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

## 项目结构

```
Sources/
├── AgoraEngineManager.swift        # 声网引擎封装
├── CallManager.swift               # 通话核心管理器
├── Model/
│   ├── CallState.swift             # 通话状态枚举
│   ├── CallType.swift              # 通话类型/模式枚举
│   ├── CallUser.swift              # 用户信息模型
│   ├── IncomingCallManager.swift   # 来电弹窗管理器
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
CallManager.shared.uiDelegate = self
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
|------|------|
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

- iOS 13.0+
- Swift 5.0+
- Agora RTC SDK（通过 CocoaPods/SPM 集成）
- AVKit（画中画功能，iOS 15.0+）
