# AgoraCallKit Example

本目录包含 AgoraCallKit 的完整使用示例，展示了各种配置模式和功能集成方式。

## 文件说明

| 文件 | 说明 |
|------|------|
| `AppDelegate.swift` | App 入口，初始化通话服务 |
| `ViewController.swift` | 示例界面，演示各种通话操作 |
| `ServiceExamples.swift` | 服务实现示例（信令、Token、用户） |
| `CallConfigurationExamples.swift` | CallKit/LiveCommunicationKit 配置示例 |
| `VoIPPushExamples.swift` | VoIP 推送集成示例 |

## 快速开始

### 1. 替换 App ID

在 `AppDelegate.swift` 中替换为你的声网 App ID：

```swift
AgoraEngineManager.shared.configure(appId: "your-agora-app-id")
```

### 2. 配置信令服务

在 `ServiceExamples.swift` 中实现 `ExampleSignalService`，接入你的信令服务器（WebSocket 等）。

### 3. 运行项目

```bash
cd Example
pod install
open Example.xcworkspace
```

## 配置模式

Example 提供了四种系统来电界面配置模式：

```swift
// 方式一：仅使用 App 内弹窗
ExampleCallServiceManager.shared.setup(mode: .appOnly)

// 方式二：启用 CallKit（所有 iOS 版本）
ExampleCallServiceManager.shared.setup(mode: .callKitOnly)

// 方式三：启用 LiveCommunicationKit（iOS 17.4+，推荐）
ExampleCallServiceManager.shared.setup(mode: .liveCommunicationKit)

// 方式四：仅 VoIP 推送时使用系统来电界面（推荐）
ExampleCallServiceManager.shared.setup(mode: .voipPushOnly)
```

## 功能演示

运行 Example App 后，可以：

1. **切换配置模式** - 测试不同的系统来电界面配置
2. **发起通话** - 测试视频/音频通话发起流程
3. **模拟来电** - 测试 App 内弹窗和系统来电界面
4. **查看状态** - 查看当前配置和通话状态

## VoIP 推送集成

### 服务端推送格式

```json
{
    "fromUserId": "12345",
    "channelName": "12345-67890",
    "token": "006xxxx...",
    "callType": "video",
    "callerName": "张三",
    "callerAvatar": "https://example.com/avatar.jpg"
}
```

### 客户端接收

VoIP 推送由 `VoIPPushExamples` 处理，自动启用系统来电界面。

## 铃声配置

在 `ServiceExamples.swift` 中配置铃声：

```swift
CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "ringtone_call", ofType: "wav")
```

注意：铃声文件需添加到 App Bundle，不可放在 Assets.xcassets。

## 注意事项

1. **VoIP 推送证书** - 需要配置 Apple VoIP Services 证书
2. **后台模式** - Info.plist 中需要添加 `voip` 后台模式
3. **测试系统界面** - 需要真机设备测试 CallKit/LiveCommunicationKit
4. **iOS 版本** - LiveCommunicationKit 需要 iOS 17.4+
