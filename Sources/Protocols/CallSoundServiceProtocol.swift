//
//  CallSoundServiceProtocol.swift
//  AgoraCallKit
//
//  声音服务协议：解耦 CallManager 与 CallSoundService，支持 Mock 测试
//

import Foundation

/// 通话声音服务协议
public protocol CallSoundServiceProtocol: AnyObject {
    /// 是否跳过音频会话配置（通话已接通时为 true）
    var bypassAudioSession: Bool { get set }
    /// 是否启用声音
    var isSoundEnabled: Bool { get set }
    /// 是否启用按键音
    var isButtonClickSoundEnabled: Bool { get set }
    /// 是否启用震动
    var isVibrationEnabled: Bool { get set }
    /// 系统铃声路径
    var incomingRingtonePath: String? { get set }
    /// 等待音路径
    var outgoingRingtonePath: String? { get set }

    /// 铃声/等待音
    func startIncomingRingtone()
    func startOutgoingRingtone()
    func stopIncomingRingtone()
    func stopOutgoingRingtone()

    /// 提示音
    func playCallConnectedSound()
    func playCallEndedSound()
    func playButtonClickSound()

    /// 停止所有
    func stopAllSounds()
}
