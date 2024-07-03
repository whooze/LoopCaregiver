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
import NightscoutKit
import SwiftUI

public struct WidgetViewModel {
    public let glucoseValue: GlucoseTimelineValue
    public let timelineEntryDate: Date
    public let latestGlucose: NewGlucoseSample
    public let lastGlucoseChange: Double?
    public let glucoseDisplayUnits: HKUnit
    public let currentProfile: ProfileSet?
    public let recentGlucoseValues: [NewGlucoseSample]

    public init(glucoseValue: GlucoseTimelineValue) {
        self.glucoseValue = glucoseValue
        self.timelineEntryDate = glucoseValue.date
        self.latestGlucose = glucoseValue.glucoseSample
        self.lastGlucoseChange = glucoseValue.lastGlucoseChange
        self.glucoseDisplayUnits = glucoseValue.glucoseDisplayUnits
        self.recentGlucoseValues = glucoseValue.recentSamples
        self.currentProfile = glucoseValue.currentProfile
    }

    public var currentGlucoseDateText: String {
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
