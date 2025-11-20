//
//  CalendarManager.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


import Foundation
import EventKit

class CalendarManager {
    private let store = EKEventStore()

    func requestAuthorization() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .event) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    print("📅 日历授权状态: \(granted)")
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchEventsLastWeek() -> [String] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        let names = events.map { $0.title }

        return names.isEmpty ? [] : names as! [String]
    }
}
