import Foundation

/// 通话相关错误类型
public enum CallError: Error, LocalizedError {
    /// 用户未登录或无法获取用户信息
    case userNotAvailable
    /// Token 获取失败
    case tokenFetchFailed(underlying: Error?)
    /// 信令发送失败
    case signalFailed(underlying: Error?)
    /// 音频会话配置失败
    case audioSessionFailed
    /// 通话超时无人接听
    case callTimeout
    /// 对方忙线
    case remoteBusy
    /// 对方拒绝
    case remoteRejected(reason: String?)
    /// 对方取消
    case remoteCanceled
    /// 引擎错误
    case engineError(underlying: Error?)
    /// 网络断开
    case networkDisconnected
    /// 状态异常
    case invalidState(current: String, expected: String)
    /// 自定义错误
    case custom(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .userNotAvailable: return "无法获取当前用户信息"
        case .tokenFetchFailed(let e): return "Token获取失败: \(e?.localizedDescription ?? "未知")"
        case .signalFailed(let e): return "信令发送失败: \(e?.localizedDescription ?? "未知")"
        case .audioSessionFailed: return "音频会话配置失败"
        case .callTimeout: return "通话超时无人接听"
        case .remoteBusy: return "对方忙线"
        case .remoteRejected(let reason): return "对方拒绝: \(reason ?? "")"
        case .remoteCanceled: return "对方已取消"
        case .engineError(let e): return "引擎错误: \(e?.localizedDescription ?? "未知")"
        case .networkDisconnected: return "网络连接断开"
        case .invalidState(let c, let e): return "状态异常: 当前\(c), 期望\(e)"
        case .custom(let msg): return msg
        }
    }
}
