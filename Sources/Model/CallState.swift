//
//  CallState.swift
//  CallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

public enum CallState: Equatable {
    case idle              // 空闲
    case calling           // 正在呼叫（主叫等待接听）
    case incoming          // 收到来电（被叫等待选择）
    case connecting        // 连接中（加入频道）
    case connected         // 通话中
    case reconnecting      // 重连中
    case disconnected      // 已断开（通话结束）
    case failed            // 失败
}
