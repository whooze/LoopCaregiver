//
//  NewGlucoseSample+Presentable.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 6/3/23.
//

import Foundation
import HealthKit
import LoopKit

public extension NewGlucoseSample {
    func presentableUserValue(displayUnits: HKUnit) -> Double {
        return quantity.doubleValue(for: displayUnits)
    }

    func presentableStringValue(displayUnits: HKUnit) -> String {
        let unitInUserUnits = quantity.doubleValue(for: displayUnits)
        return LocalizationUtils.presentableStringFromGlucoseAmount(unitInUserUnits, displayUnits: displayUnits)
    }
}

public extension [NewGlucoseSample] {
    func getLastGlucoseChange(displayUnits: HKUnit) -> Double? {
        guard count > 1 else {
            return nil
        }
        let lastGlucoseValue = self[count - 1].presentableUserValue(displayUnits: displayUnits)
        let priorGlucoseValue = self[count - 2].presentableUserValue(displayUnits: displayUnits)
        return lastGlucoseValue - priorGlucoseValue
    }
}
