//
//  SimpleEntry.swift
//  LoopCaregiverWidgetExtension
//
//  Created by Bill Gestrich on 6/2/23.
//

import Foundation
import LoopCaregiverKit
import LoopKit
import WidgetKit

struct SimpleEntry: TimelineEntry {
    let looper: Looper?
    let currentGlucoseSample: NewGlucoseSample?
    let lastGlucoseChange: Double?
    let error: Error?
    let date: Date
    let entryIndex: Int
    let isLastEntry: Bool

    func nextExpectedGlucoseDate() -> Date? {
        let secondsBetweenSamples: TimeInterval = 60 * 5

        guard let glucoseDate = currentGlucoseSample?.date else {
            return nil
        }

        return glucoseDate.addingTimeInterval(secondsBetweenSamples)
    }
}
