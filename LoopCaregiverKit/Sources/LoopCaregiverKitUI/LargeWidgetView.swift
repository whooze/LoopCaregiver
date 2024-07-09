//
//  LargeWidgetView.swift
//
//
//  Created by Bill Gestrich on 7/8/24.
//

import Foundation
import LoopCaregiverKit
import SwiftUI

public struct LargeWidgetView: View {
    public let viewModel: WidgetViewModel
    
    public init(glucoseValue: GlucoseTimelineValue) {
        self.viewModel = WidgetViewModel(glucoseValue: glucoseValue)
    }
    
    public var body: some View {
        VStack {
            HStack {
                CurrentGlucoseComboView(glucoseSample: viewModel.latestGlucose, lastGlucoseChange: viewModel.lastGlucoseChange, displayUnits: viewModel.glucoseDisplayUnits)
                Spacer()
            }
            if let (override, status) = viewModel.glucoseValue.treatmentData.overrideAndStatus {
                ActiveOverrideInlineView(activeOverride: override, status: status)
            }
            NightscoutChartView(
                viewModel: NightscoutChartViewModel(
                    treatmentData: viewModel.treatmentData,
                    timelinePredictionEnabled: true,
                    totalLookbackhours: 6,
                    timelineVisibleLookbackHours: 6,
                    showChartXAxis: true,
                    showChartYAxis: true
                )
            )
        }
    }
}
