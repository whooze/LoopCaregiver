//
//  LatestGlucoseRectangularView.swift
//  LoopCaregiverWidgetExtension
//
//  Created by Auggie Fisher on 1/24/24.
//

import Charts
import HealthKit
import LoopCaregiverKit
import LoopKit
import SwiftUI

public struct LatestGlucoseRectangularView: View {
    public let viewModel: WidgetViewModel
    @Environment(\.colorScheme)
    var colorScheme

    public init(glucoseValue: GlucoseTimelineValue) {
        self.viewModel = WidgetViewModel(glucoseValue: glucoseValue)
    }

    public var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // BG number
                        Text(viewModel.currentGlucoseNumberText)
                            .foregroundStyle(egvColor)
                            .strikethrough(viewModel.isGlucoseStale)
                            .font(.headline)
                            .minimumScaleFactor(0.6)
                    // Trend arrow
                    if let currentTrendImageName = viewModel.currentTrendImageName {
                        Image(systemName: currentTrendImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 12)
                            .offset(.init(width: 0.0, height: 1.5))
                            .accessibilityLabel(Text(currentTrendImageName))
                            .padding(.init(top: 0, leading: 2, bottom: 0, trailing: 0))
                    }
                    // Age
                    Text(viewModel.currentGlucoseDateText)
                        .strikethrough(viewModel.isGlucoseStale)
                        .font(.headline)
                        .padding(.init(top: 0, leading: 5, bottom: 0, trailing: 0))
                    Spacer()
                }
                chart
                .padding(.init(top: 0, leading: 0, bottom: 5, trailing: 0))
            }
    }
    
    var egvColor: Color {
        colorScheme == .dark ? viewModel.egvValueColor : .primary
    }
    
    @ViewBuilder var chart: some View {
        Chart {
            ForEach(viewModel.recentGlucoseValues.filter({ $0.date > chartXRange().lowerBound }), id: \.date) {
                PointMark(
                    x: .value("Time", $0.date),
                    y: .value("Reading", $0.quantity.doubleValue(for: viewModel.glucoseDisplayUnits))
                )
                .symbol(
                    FilledCircle()
                )
            }
        }
        .chartXAxis(.hidden)
        .chartXScale(domain: chartXRange())
    }
    
    func chartXRange() -> ClosedRange<Date> {
        let maxXDate = Date()
        let minXDate = Date().addingTimeInterval(-60 * 60 * 2)
        return minXDate...maxXDate
    }
}

struct LatestGlucoseRectangularView_Previews: PreviewProvider {
    static var previews: some View {
        LatestGlucoseRectangularView(glucoseValue: .previewsValue())
    }
}
