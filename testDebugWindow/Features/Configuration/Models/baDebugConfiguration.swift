import Foundation


/// 调试窗口配置
struct DebugConfiguration: Codable {
    // 窗口配置
    struct WindowConfig: Codable {
        var defaultWidth: CGFloat
        var defaultHeight: CGFloat
        var minWidth: CGFloat
        var minHeight: CGFloat
        var snapDistance: CGFloat
        var animationDuration: Double

        static let `default` = WindowConfig(
            defaultWidth: 400,
            defaultHeight: 600,
            minWidth: 300,
            minHeight: 200,
            snapDistance: 70,
            animationDuration: 0.24
        )
    }

    struct baDebugWindowConfig: Codable {
        var position: CGPoint
        var size: CGSize
    }

    // 性能监控配置
    struct PerformanceConfig: Codable {
        var updateInterval: TimeInterval
        var maxHistoryCount: Int
        var enableCPUMonitoring: Bool
        var enableMemoryMonitoring: Bool
        var enableFPSMonitoring: Bool

        static let `default` = PerformanceConfig(
            updateInterval: 1.0,
            maxHistoryCount: 100,
            enableCPUMonitoring: true,
            enableMemoryMonitoring: true,
            enableFPSMonitoring: true
        )
    }

    // 日志配置
    struct LogConfig: Codable {
        var maxMessageCount: Int
        var messageRetentionPeriod: TimeInterval
        var autoExportEnabled: Bool
        var exportInterval: TimeInterval

        static let `default` = LogConfig(
            maxMessageCount: 1000,
            messageRetentionPeriod: 3600,
            autoExportEnabled: false,
            exportInterval: 3600
        )
    }

    var window: WindowConfig
    var performance: PerformanceConfig
    var log: LogConfig

    static let `default` = DebugConfiguration(
        window: .default,
        performance: .default,
        log: .default
    )
}