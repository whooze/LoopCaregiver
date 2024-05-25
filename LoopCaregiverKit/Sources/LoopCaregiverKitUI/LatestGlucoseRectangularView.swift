//
//  LatestGlucoseRectangularView.swift
//  LoopCaregiverWidgetExtension
//
//  Created by Auggie Fisher on 1/24/24.
//

import HealthKit
import LoopCaregiverKit
import LoopKit
import SwiftUI

public struct LatestGlucoseRectangularView: View {
    public let viewModel: WidgetViewModel
    @Environment(\.colorScheme)
    var colorScheme
    
    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            VStack {
                // BG number
                Text(viewModel.currentGlucoseNumberText)
                    .foregroundStyle(egvColor)
                    .strikethrough(viewModel.isGlucoseStale)
                    .font(.system(size: 60.0))
            }
            VStack(spacing: 0) {
                HStack {
                    // Trend arrow
                    if let currentTrendImageName = viewModel.currentTrendImageName {
                        Image(systemName: currentTrendImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 12)
                            .offset(.init(width: 0.0, height: 1.5))
                            .accessibilityLabel(Text(currentTrendImageName))
                    }
                    // BG delta
                    Text(viewModel.lastGlucoseChangeFormatted!)
                        .strikethrough(viewModel.isGlucoseStale)
                        .font(.system(size: 20.0))
                }
                // Minutes since update
                Text(viewModel.currentGlucoseDateText)
                    .strikethrough(viewModel.isGlucoseStale)
                    .font(.system(size: 20.0))
            }
        }
    }
    
    var egvColor: Color {
        colorScheme == .dark ? viewModel.egvValueColor : .primary
    }
}

struct LatestGlucoseRectangularView_Previews: PreviewProvider {
    static var previews: some View {
        let latestGlucose = NewGlucoseSample(date: Date().addingTimeInterval(-60 * 5 * 60), quantity: .init(unit: .milligramsPerDeciliter, doubleValue: 100), condition: .aboveRange, trend: .flat, trendRate: .none, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "12345")
        let viewModel = WidgetViewModel(timelineEntryDate: Date(), latestGlucose: latestGlucose, lastGlucoseChange: 1, isLastEntry: true, glucoseDisplayUnits: .milligramsPerDeciliter, looper: nil)
        LatestGlucoseRectangularView(viewModel: viewModel)
    }
}
