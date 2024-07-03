//
//  GlucoseTimeLineEntry.swift
//  LoopCaregiverKit
//
//  Created by Bill Gestrich on 12/18/23.
//

import Foundation
import HealthKit
import LoopKit
import NightscoutKit
import WidgetKit

public enum GlucoseTimeLineEntry: TimelineEntry {
    case success(GlucoseTimelineValue)
    case failure(GlucoseTimeLineEntryError)
    
    public init(looper: Looper, glucoseSample: NewGlucoseSample, lastGlucoseChange: Double?, glucoseDisplayUnits: HKUnit, overrideAndStatus: (override: NightscoutKit.TemporaryScheduleOverride, status: NightscoutKit.OverrideStatus)?, recentSamples: [NewGlucoseSample], currentProfile: ProfileSet?, date: Date) {
        self = .success(GlucoseTimelineValue(looper: looper, glucoseSample: glucoseSample, lastGlucoseChange: lastGlucoseChange, glucoseDisplayUnits: glucoseDisplayUnits, overrideAndStatus: overrideAndStatus, recentSamples: recentSamples, currentProfile: currentProfile, date: date))
    }
    
    public init(value: GlucoseTimelineValue) {
        self = .success(value)
    }
    
    public init(error: Error, date: Date, looper: Looper?) {
        self = .failure(GlucoseTimeLineEntryError(error: error, date: date, looper: looper))
    }
    
    public var date: Date {
        switch self {
        case .success(let glucoseEntry):
            return glucoseEntry.date
        case .failure(let error):
            return error.date
        }
    }
    
    public static func previewsEntry() -> GlucoseTimeLineEntry {
        return GlucoseTimeLineEntry(value: GlucoseTimelineValue.previewsValue())
    }
}

public struct GlucoseTimelineValue {
    // TODO: It may be best to use the Looper ID and Looper name. Maybe introduce an entry configuration object for those? Need to consider if the name changes in Loop.
    public let looper: Looper
    public let glucoseSample: NewGlucoseSample
    public let lastGlucoseChange: Double?
    public let glucoseDisplayUnits: HKUnit
    public let overrideAndStatus: (override: NightscoutKit.TemporaryScheduleOverride, status: NightscoutKit.OverrideStatus)?
    public let recentSamples: [NewGlucoseSample]
    public let currentProfile: ProfileSet?
    public let date: Date
    
    public func nextExpectedGlucoseDate() -> Date {
        let secondsBetweenSamples: TimeInterval = 60 * 5
        return glucoseSample.date.addingTimeInterval(secondsBetweenSamples)
    }
    
    public func valueWithDate(_ date: Date) -> GlucoseTimelineValue {
        return .init(looper: looper, glucoseSample: glucoseSample, lastGlucoseChange: lastGlucoseChange, glucoseDisplayUnits: glucoseDisplayUnits, overrideAndStatus: overrideAndStatus, recentSamples: recentSamples, currentProfile: currentProfile, date: date)
    }
    
    public static func previewsValue() -> GlucoseTimelineValue {
        GlucoseTimelineValue(
            looper: Looper(identifier: UUID(), name: "Brian", nightscoutCredentials: .init(url: URL(string: "http://www.example.com")!, secretKey: "12345", otpURL: "12345"), lastSelectedDate: Date()),
            glucoseSample: .previews(),
            lastGlucoseChange: 10,
            glucoseDisplayUnits: .milligramsPerDeciliter,
            overrideAndStatus: nil,
            recentSamples: [],
            currentProfile: nil,
            date: Date()
        )
    }
}

public struct GlucoseTimeLineEntryError: LocalizedError {
    let error: Error
    public let date: Date
    public let looper: Looper?
    public var errorDescription: String? {
        return error.localizedDescription
    }
}
