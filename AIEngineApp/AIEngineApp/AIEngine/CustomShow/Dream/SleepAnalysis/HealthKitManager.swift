//
//  HealthKitManager.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


import Foundation
import HealthKit

// 模拟健康数据的结构体
struct SleepAnalysis {
    var averageSleepHours: Double
    var stressfulNights: Int // 例如，心率过高的夜晚
}
class HealthKitManager {

    private let store = HKHealthStore()

    // MARK: - 检查是否支持
    func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - 请求访问用户健康权限
    func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable() else { return false }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        let toShare: Set<HKSampleType> = []
        let toRead: Set<HKObjectType> = [sleepType, heartRateType]

        return try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: toShare, read: toRead) { success, error in
                if let error = error {
                    print("❌ HealthKit 授权失败：\(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ HealthKit 授权成功：\(success)")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - 获取睡眠数据（最近一周）
    func fetchSleepDataLastWeek() async throws -> SleepAnalysis {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: SleepAnalysis(averageSleepHours: 0, stressfulNights: 0))
                    return
                }

                // 计算睡眠时长
                let totalHours = samples.reduce(0.0) { sum, sample in
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    return sum + duration
                }

                let averageHours = totalHours / 7.0

                // 作为示例，我们用“心率过高的夜晚”代表压力夜（下面 EventKit 也会结合）
                let stressfulNights = max(Int.random(in: 0...3), 0)

                continuation.resume(
                    returning: SleepAnalysis(averageSleepHours: averageHours, stressfulNights: stressfulNights)
                )
            }

            store.execute(query)
        }
    }
}
