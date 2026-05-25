//
//  AgoraLogger.swift
//  AgoraCallKit
//
//  统一日志管理器，集中管理所有模块的日志输出
//

import Foundation

// MARK: - 日志级别

/// 日志级别，按严重程度递增
public enum AgoraLogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 4

    public static func < (lhs: AgoraLogLevel, rhs: AgoraLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var prefix: String {
        switch self {
        case .debug:   return "🔍"
        case .info:    return "ℹ️"
        case .warning: return "⚠️"
        case .error:   return "❌"
        case .none:    return ""
        }
    }
}

// MARK: - 日志管理器

/// 统一日志输出管理器，线程安全，支持按模块和级别过滤
public final class AgoraLogger {

    // MARK: - 单例

    public static let shared = AgoraLogger()

    /// 外部可注入的输出闭包（默认 print），便于测试或重定向到文件
    public var output: (String) -> Void = { print($0) }

    /// 最低输出级别，低于此级别的日志会被丢弃
    public var minimumLevel: AgoraLogLevel = {
        #if DEBUG
        return .debug
        #else
        return .warning
        #endif
    }()

    private let queue = DispatchQueue(label: "com.agora.callkit.logger", qos: .utility)

    private init() {}

    // MARK: - 公共接口

    /// 输出日志
    /// - Parameters:
    ///   - message: 日志内容（闭包形式，仅在级别满足条件时求值）
    ///   - level: 日志级别
    ///   - module: 模块名，用于识别日志来源
    ///   - function: 调用函数名（自动获取）
    ///   - file: 源文件名（自动获取，仅 debug 级别输出）
    ///   - line: 行号（自动获取，仅 debug 级别输出）
    public func log(
        _ message: @autoclosure () -> String,
        level: AgoraLogLevel = .info,
        module: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        guard level.rawValue >= minimumLevel.rawValue else { return }

        let msg: String
        if minimumLevel == .debug {
            let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
            msg = "\(level.prefix) [\(module)] \(fileName).\(function):\(line) | \(message())"
        } else {
            msg = "\(level.prefix) [\(module)] \(function) | \(message())"
        }

        queue.async { [output] in
            output(msg)
        }
    }

    // MARK: - 便捷方法

    /// debug 级别日志
    public static func debug(
        _ message: @autoclosure () -> String,
        module: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        shared.log(message(), level: .debug, module: module, function: function, file: file, line: line)
    }

    /// info 级别日志
    public static func info(
        _ message: @autoclosure () -> String,
        module: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        shared.log(message(), level: .info, module: module, function: function, file: file, line: line)
    }

    /// warning 级别日志
    public static func warning(
        _ message: @autoclosure () -> String,
        module: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        shared.log(message(), level: .warning, module: module, function: function, file: file, line: line)
    }

    /// error 级别日志
    public static func error(
        _ message: @autoclosure () -> String,
        module: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        shared.log(message(), level: .error, module: module, function: function, file: file, line: line)
    }
}
