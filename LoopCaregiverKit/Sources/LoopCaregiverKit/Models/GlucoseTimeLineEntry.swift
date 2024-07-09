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
    
    public init(looper: Looper, glucoseSample: NewGlucoseSample, treatmentData: CaregiverTreatmentData, date: Date) {
        self = .success(
            GlucoseTimelineValue(
                looper: looper,
                glucoseSample: glucoseSample,
                treatmentData: treatmentData,
                date: date
            )
        )
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
    public let treatmentData: CaregiverTreatmentData
    public let date: Date
    
    public init(
        looper: Looper,
        glucoseSample: NewGlucoseSample,
        treatmentData: CaregiverTreatmentData,
        date: Date
    ) {
        self.looper = looper
        self.glucoseSample = glucoseSample
        self.treatmentData = treatmentData
        self.date = date
    }
    
    public func nextExpectedGlucoseDate() -> Date {
        let secondsBetweenSamples: TimeInterval = 60 * 5
        return glucoseSample.date.addingTimeInterval(secondsBetweenSamples)
    }
    
    public func valueWithDate(_ date: Date) -> GlucoseTimelineValue {
        return .init(
            looper: looper,
            glucoseSample: glucoseSample,
            treatmentData: treatmentData,
            date: date
        )
    }
    
    public static func previewsValue() -> GlucoseTimelineValue {
        var recentSamples = [NewGlucoseSample]()
        for index in 0..<600 {
            recentSamples.append(
                NewGlucoseSample(
                    date: Date().addingTimeInterval(Double(-index * 60 * 5)),
                    quantity: .init(unit: .milligramsPerDeciliter, doubleValue: Double(60 + index)),
                    condition: .none,
                    trend: .flat,
                    trendRate: .none,
                    isDisplayOnly: false,
                    wasUserEntered: false,
                    syncIdentifier: "1345"
                )
            )
        }
        
        let treatmentData = CaregiverTreatmentData(
            glucoseDisplayUnits: .milligramsPerDeciliter,
            glucoseSamples: recentSamples,
            predictedGlucose: [],
            bolusEntries: [],
            carbEntries: [],
            recentCommands: [],
            currentProfile: nil,
            overrideAndStatus: nil
        )
        
        return GlucoseTimelineValue(
            looper: Looper(
                identifier: UUID(),
                name: "Brian",
                nightscoutCredentials: .init(url: URL(string: "http://www.example.com")!, secretKey: "12345", otpURL: "12345"),
                lastSelectedDate: Date()
            ),
            glucoseSample: .previews(),
            treatmentData: treatmentData,
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
