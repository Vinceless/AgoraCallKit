//
//  VideoRendererBinder.swift
//  AgoraCallKit
//
//  视频渲染绑定器：统一管理视频渲染目标在 VC 和悬浮窗之间的迁移，避免 dangling pointer
//

import UIKit

/// 视频渲染绑定器：持有视频渲染视图，统一管理渲染目标的迁移
public final class VideoRendererBinder {

    /// 当前视频渲染视图（弱引用避免内存泄漏，由 VC/悬浮窗控制生命周期）
    public private(set) weak var renderView: UIView?

    /// 渲染视图所在的容器（强引用，保证迁移期间视图不被释放）
    private var retainedView: UIView?

    /// 是否在悬浮窗模式
    public private(set) var isInFloatingMode = false

    /// 远端用户 uid（用于重新绑定）
    public private(set) var remoteUid: UInt = 0

    // MARK: - 视图绑定

    /// 将远端视频绑定到指定视图，并持有强引用防止迁移时丢失
    /// - Parameters:
    ///   - view: 视频渲染目标视图
    ///   - uid: 远端用户 uid
    ///   - engine: 引擎管理器（用于重新绑定）
    public func bind(view: UIView, remoteUid uid: UInt, engine: AgoraEngineManager) {
        retainedView = view
        renderView = view
        remoteUid = uid
        engine.setupRemoteVideoView(view, forUid: uid)
    }

    /// 迁移到悬浮窗
    /// - Parameters:
    ///   - floatingView: 悬浮窗中的视频容器视图
    ///   - engine: 引擎管理器
    public func migrateToFloatingWindow(containerView: UIView, engine: AgoraEngineManager) {
        // 先清除远端视频渲染，避免旧视图成为 dangling
        engine.removeRemoteVideoView(forUid: remoteUid)
        isInFloatingMode = true
        retainedView = containerView
        renderView = containerView
        engine.setupRemoteVideoView(containerView, forUid: remoteUid)
    }

    /// 从悬浮窗恢复到全屏
    /// - Parameters:
    ///   - restoreView: 恢复到的目标视图
    ///   - engine: 引擎管理器
    public func restoreToFullScreen(restoreView: UIView, engine: AgoraEngineManager) {
        engine.removeRemoteVideoView(forUid: remoteUid)
        isInFloatingMode = false
        retainedView = restoreView
        renderView = restoreView
        engine.setupRemoteVideoView(restoreView, forUid: remoteUid)
    }

    /// 获取当前渲染视图并从绑定器分离（迁移到悬浮窗时调用，由悬浮窗接管生命周期）
    /// - Returns: 当前视频渲染视图（弱引用被提升为强引用）
    public func detachAndGetView() -> UIView? {
        let view = retainedView
        renderView = nil
        return view
    }

    /// 从悬浮窗恢复后重新绑定
    /// - Parameters:
    ///   - view: 从悬浮窗返回的视频视图
    ///   - engine: 引擎管理器
    public func rebindFromFloating(view: UIView, engine: AgoraEngineManager) {
        retainedView = view
        renderView = view
        isInFloatingMode = false
        engine.setupRemoteVideoView(view, forUid: remoteUid)
    }

    /// 清理所有引用（通话结束时调用）
    public func cleanup(engine: AgoraEngineManager) {
        engine.removeRemoteVideoView(forUid: remoteUid)
        renderView = nil
        retainedView = nil
        remoteUid = 0
        isInFloatingMode = false
    }
}
