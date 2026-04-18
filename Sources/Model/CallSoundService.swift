//
//  CallSoundService.swift
//  AgoraCallKit
//
//  通话声音/震动服务：负责来电彩铃、呼叫等待音、接听/挂断音、按键点击音、震动
//

import Foundation
import AVFoundation
import AudioToolbox

/// 通话声音/震动管理器
/// - 来电彩铃：被叫收到来电时播放（默认系统铃声，可自定义本地音频文件）
/// - 呼叫等待音：主叫发起通话后播放（系统回铃音）
/// - 接听/挂断音：通话接通/断开时的提示音
/// - 按键点击音：功能按钮点击音效
/// - 震动：来电震动反馈
public class CallSoundService {
    
    public static let shared = CallSoundService()
    
    private init() {}
    
    // MARK: - 音频播放器
    
    /// 彩铃/回铃音播放器（支持循环播放）
    private var ringtonePlayer: AVAudioPlayer?
    /// 短提示音播放器
    private var effectPlayer: AVAudioPlayer?
    
    /// 是否正在播放铃声
    public private(set) var isPlayingRingtone: Bool = false
    
    // MARK: - 可配置属性
    
    /// 来电彩铃音频文件路径（nil 则使用系统铃声震动）
    /// App 端可设置本地音频文件路径作为自定义彩铃
    /// 例: CallSoundService.shared.incomingRingtonePath = Bundle.main.path(forResource: "my_ringtone", ofType: "mp3")
    public var incomingRingtonePath: String?
    
    /// 呼叫等待音音频文件路径（nil 则使用系统回铃音）
    public var outgoingRingtonePath: String?
    
    /// 接听提示音音频文件路径
    public var callConnectedSoundPath: String?
    
    /// 挂断提示音音频文件路径
    public var callEndedSoundPath: String?
    
    /// 按键点击音音频文件路径
    public var buttonClickSoundPath: String?
    
    /// 是否启用声音（默认 true，设为 false 则所有铃声/提示音/按键音都不播放，仅保留震动）
    public var isSoundEnabled: Bool = true
    
    /// 是否启用按键点击音（默认 true）
    public var isButtonClickSoundEnabled: Bool = true
    
    /// 是否启用来电震动（默认 true）
    public var isVibrationEnabled: Bool = true
    
    /// 是否使用系统铃声（默认 true，当 incomingRingtonePath 为 nil 时生效）
    /// 系统铃声会配合震动一起播放
    public var useSystemRingtone: Bool = true
    
    // MARK: - 震动相关
    
    /// 来电震动定时器
    private var vibrationTimer: Timer?
    
    /// 系统铃声震动模式定时器
    private var systemRingtoneTimer: Timer?
    
    // MARK: - 音频会话管理
    
    /// 配置音频会话（播放铃声前调用）
    private func configureAudioSession(forPlayback: Bool = true) {
        let session = AVAudioSession.sharedInstance()
        do {
            if forPlayback {
                try session.setCategory(.playback, mode: .voiceChat, options: [.mixWithOthers])
            } else {
                try session.setCategory(.ambient, mode: .default)
            }
            try session.setActive(true)
        } catch {
            print("[CallSoundService] 配置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    /// 恢复音频会话为通话模式
    private func restoreAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voiceChat)
            try session.setActive(true)
        } catch {
            print("[CallSoundService] 恢复音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 来电彩铃（被叫）
    
    /// 开始播放来电彩铃 + 震动
    public func startIncomingRingtone() {
        print("[CallSoundService] 开始来电彩铃")
        stopAllSounds()
        
        if isSoundEnabled {
            if let path = incomingRingtonePath {
                // 自定义彩铃音频文件
                playRingtoneFile(at: path, loops: -1)
                startIncomingVibration()
            } else if useSystemRingtone {
                // 使用系统铃声震动模式
                startSystemRingtoneVibration()
            } else {
                // 仅震动
                startIncomingVibration()
            }
        } else {
            // 声音禁用，仅震动
            startIncomingVibration()
        }
        
        isPlayingRingtone = true
    }
    
    /// 停止来电彩铃
    public func stopIncomingRingtone() {
        print("[CallSoundService] 停止来电彩铃")
        stopRingtonePlayer()
        stopVibration()
        stopSystemRingtone()
        isPlayingRingtone = false
    }
    
    // MARK: - 呼叫等待音（主叫）
    
    /// 开始播放呼叫等待音（主叫拨出后等待对方接听）
    public func startOutgoingRingtone() {
        print("[CallSoundService] 开始呼叫等待音")
        stopAllSounds()
        
        if isSoundEnabled {
            if let path = outgoingRingtonePath {
                // 自定义回铃音音频文件
                playRingtoneFile(at: path, loops: -1)
            } else {
                // 使用系统回铃音（Simulated carrier ringback tone）
                playSystemOutgoingSound()
            }
        }
        // 声音禁用时不播放任何声音，主叫端不需要震动
        
        isPlayingRingtone = isSoundEnabled
    }
    
    /// 停止呼叫等待音
    public func stopOutgoingRingtone() {
        print("[CallSoundService] 停止呼叫等待音")
        stopRingtonePlayer()
        stopSystemRingtone()
        isPlayingRingtone = false
    }
    
    // MARK: - 接通/挂断提示音
    
    /// 播放接通提示音
    public func playCallConnectedSound() {
        print("[CallSoundService] 播放接通提示音")
        guard isSoundEnabled else { return }
        if let path = callConnectedSoundPath {
            playEffectSound(at: path)
        } else {
            // 系统接通音：短促的提示音
            playSystemSound(1057) // keynote_sound
        }
    }
    
    /// 播放挂断提示音
    public func playCallEndedSound() {
        print("[CallSoundService] 播放挂断提示音")
        guard isSoundEnabled else { return }
        if let path = callEndedSoundPath {
            playEffectSound(at: path)
        } else {
            // 系统挂断音
            playSystemSound(1073) // Tink
        }
    }
    
    // MARK: - 按键点击音
    
    /// 播放按钮点击音
    public func playButtonClickSound() {
        guard isSoundEnabled, isButtonClickSoundEnabled else { return }
        if let path = buttonClickSoundPath {
            playEffectSound(at: path)
        } else {
            // 系统键盘点击音
            playSystemSound(1104) // keyboard_click
        }
    }
    
    // MARK: - 停止所有声音
    
    /// 停止所有声音和震动
    public func stopAllSounds() {
        stopRingtonePlayer()
        stopEffectPlayer()
        stopVibration()
        stopSystemRingtone()
        isPlayingRingtone = false
    }
    
    // MARK: - 私有方法 - 文件播放
    
    /// 播放铃声文件（支持循环）
    private func playRingtoneFile(at path: String, loops: Int = 0) {
        let url = URL(fileURLWithPath: path)
        do {
            configureAudioSession(forPlayback: true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = loops
            player.prepareToPlay()
            player.play()
            ringtonePlayer = player
        } catch {
            print("[CallSoundService] 播放铃声文件失败: \(path), error: \(error.localizedDescription)")
        }
    }
    
    /// 播放短提示音文件
    private func playEffectSound(at path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            configureAudioSession(forPlayback: false)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.prepareToPlay()
            player.play()
            effectPlayer = player
        } catch {
            print("[CallSoundService] 播放提示音文件失败: \(path), error: \(error.localizedDescription)")
        }
    }
    
    private func stopRingtonePlayer() {
        // 先将音量设为0再停止，避免 AVAudioPlayer.stop() 后缓冲区残留音频继续播放
        ringtonePlayer?.volume = 0
        ringtonePlayer?.stop()
        ringtonePlayer = nil
    }
    
    private func stopEffectPlayer() {
        effectPlayer?.stop()
        effectPlayer = nil
    }
    
    // MARK: - 私有方法 - 系统声音
    
    /// 播放系统声音（短音效）
    private func playSystemSound(_ systemSoundID: SystemSoundID) {
        AudioServicesPlaySystemSound(systemSoundID)
    }
    
    // MARK: - 私有方法 - 系统回铃音（主叫等待音）
    
    /// 使用系统声音模拟回铃音
    /// iOS 没有公开的回铃音 API，这里用系统 DTMF 音模拟
    /// 440Hz + 480Hz 的组合是美国标准回铃音
    private func playSystemOutgoingSound() {
        // 使用系统铃声音效 1053 作为简化方案
        // 更好的方案是使用自定义音频文件
        playSystemSound(1053)
    }
    
    // MARK: - 私有方法 - 震动
    
    /// 开始来电震动（模拟电话铃声震动节奏）
    /// 系统来电铃声节奏: 震动2秒 -> 静音1秒 -> 循环
    private func startIncomingVibration() {
        guard isVibrationEnabled else { return }
        stopVibration()
        
        // 立即震动一次
        triggerVibration()
        
        // 按节奏循环震动
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.triggerVibration()
        }
        RunLoop.main.add(vibrationTimer!, forMode: .common)
    }
    
    /// 触发一次震动
    private func triggerVibration() {
        guard isVibrationEnabled else { return }
        // 来电使用持续震动模式
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    /// 停止震动
    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }
    
    // MARK: - 私有方法 - 系统铃声震动模式
    
    /// 使用 AudioServicesPlaySystemSound 播放系统铃声
    /// kSystemSoundID_Vibrate 只是一次震动
    /// 通过定时器模拟系统铃声的节奏
    private func startSystemRingtoneVibration() {
        guard isVibrationEnabled else { return }
        stopSystemRingtone()
        
        // iOS 没有公开 API 直接播放电话铃声
        // 使用系统音效 + 震动模拟
        // 播放系统通知音 + 震动
        playSystemSoundAndVibrate()
        
        // 模拟铃声节奏：响2秒，停1秒
        var isOn = true
        systemRingtoneTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if isOn {
                self.playSystemSoundAndVibrate()
            }
            isOn = !isOn
        }
        RunLoop.main.add(systemRingtoneTimer!, forMode: .common)
    }
    
    /// 播放系统通知音 + 震动
    private func playSystemSoundAndVibrate() {
        if isSoundEnabled {
            // 系统收到消息的音效
            AudioServicesPlaySystemSound(1002) // Tock
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    /// 停止系统铃声模式
    private func stopSystemRingtone() {
        systemRingtoneTimer?.invalidate()
        systemRingtoneTimer = nil
    }
}
