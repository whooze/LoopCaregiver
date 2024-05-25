//
//  WidgetViewModel.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 1/2/24.
//

import Foundation
import HealthKit
import LoopCaregiverKit
import LoopKit
import SwiftUI

public struct WidgetViewModel {
    public let timelineEntryDate: Date
    public let latestGlucose: NewGlucoseSample
    public let lastGlucoseChange: Double?
    public let isLastEntry: Bool
    public let glucoseDisplayUnits: HKUnit
    public let looper: Looper?

    public init(timelineEntryDate: Date, latestGlucose: NewGlucoseSample, lastGlucoseChange: Double? = nil, isLastEntry: Bool, glucoseDisplayUnits: HKUnit, looper: Looper?) {
        self.timelineEntryDate = timelineEntryDate
        self.latestGlucose = latestGlucose
        self.lastGlucoseChange = lastGlucoseChange
        self.isLastEntry = isLastEntry
        self.glucoseDisplayUnits = glucoseDisplayUnits
        self.looper = looper
    }

    public var currentGlucoseDateText: String {
        if isLastEntry {
            return ""
        }
        let elapsedMinutes: Double = timelineEntryDate.timeIntervalSince(latestGlucose.date) / 60.0
        let roundedMinutes = Int(exactly: elapsedMinutes.rounded(.up)) ?? 0
        return "\(roundedMinutes)m"
    }

    public var isGlucoseStale: Bool {
        return latestGlucose.date < timelineEntryDate.addingTimeInterval(-60 * 15)
    }

    public var currentGlucoseText: String {
        var toRet = ""
        let latestGlucoseValue = latestGlucose.presentableStringValue(displayUnits: glucoseDisplayUnits, includeShortUnits: false)
        toRet += "\(latestGlucoseValue)"

        if let lastGlucoseChangeFormatted {
            toRet += " \(lastGlucoseChangeFormatted)"
        }

        return toRet
    }
    
    public var currentGlucoseNumberText: String {
        var toRet = ""
        let latestGlucoseValue = latestGlucose.presentableStringValue(displayUnits: glucoseDisplayUnits, includeShortUnits: false)
        toRet += "\(latestGlucoseValue)"
        
        return toRet
    }
    
    public var lastGlucoseChangeFormatted: String? {
        guard let lastGlucoseChange else {return nil}

        guard lastGlucoseChange != 0 else {return nil}

        return lastGlucoseChange.formatted(
            .number
                .sign(strategy: .always(includingZero: false))
            .precision(.fractionLength(0...1))
        )
    }

    public var currentTrendImageName: String? {
        guard let trend = latestGlucose.trend else {
            return nil
        }

        switch trend {
        case .up:
            return "arrow.up.forward"
        case .upUp:
            return "arrow.up"
        case .upUpUp:
            return "arrow.up"
        case .flat:
            return "arrow.right"
        case .down:
            return "arrow.down.forward"
        case .downDown:
            return "arrow.down"
        case .downDownDown:
            return "arrow.down"
        }
    }

    public var egvValueColor: Color {
        return ColorType(quantity: latestGlucose.quantity).color
    }

    var timeFormat: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }
}
