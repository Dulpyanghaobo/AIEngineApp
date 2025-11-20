import Foundation
import FoundationModels

struct CorrelateWithRealWorldDataTool: Tool {

    private let healthManager: HealthKitManager
    private let calendarManager: CalendarManager

    init(healthManager: HealthKitManager, calendarManager: CalendarManager) {
        self.healthManager = healthManager
        self.calendarManager = calendarManager
    }

    @Generable
    struct Arguments {
        var period: String  // e.g. "last_week"
    }

    typealias Output = RealWorldContext

    let name = "correlateWithRealWorldData"
    let description = "Retrieve real Health & Calendar data (with permissions) and find correlations."

    func call(arguments: Arguments) async throws -> Output {

        // 1. 权限请求
        async let healthAuth = healthManager.requestAuthorization()
        async let calendarAuth = calendarManager.requestAuthorization()

        let (healthGranted, calendarGranted) = try await (healthAuth, calendarAuth)

        var sleep: SleepAnalysis?
        if healthGranted {
            sleep = try? await healthManager.fetchSleepDataLastWeek()
        }

        var events: [String] = []
        if calendarGranted {
            events = calendarManager.fetchEventsLastWeek()
        }

        // 2. 构建 summary
        var summary = ""

        if let sleep {
            summary += "过去一周平均睡眠 \(String(format: "%.1f", sleep.averageSleepHours)) 小时，有 \(sleep.stressfulNights) 个压力夜。"
        } else {
            summary += "未能访问睡眠数据。"
        }

        if !events.isEmpty {
            summary += " 日历中出现这些可能带来压力的事件：\(events.joined(separator: ", "))."
        } else {
            summary += " 日历中没有明显的压力事件。"
        }

        return RealWorldContext(
            averageSleepHours: sleep?.averageSleepHours,
            stressfulNights: sleep?.stressfulNights,
            significantEvents: events,
            summary: summary
        )
    }
}
