//
//  LatestGlucoseCircularView.swift
//  LoopCaregiverWidgetExtension
//
//  Created by Bill Gestrich on 6/3/23.
//

import HealthKit
import LoopCaregiverKit
import LoopKit
import SwiftUI

public struct LatestGlucoseCircularView: View {
    public let viewModel: WidgetViewModel
    @Environment(\.colorScheme)
    var colorScheme

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack {
            Text(viewModel.currentGlucoseDateText)
                .strikethrough(viewModel.isGlucoseStale)
                .font(.footnote)
            Text(viewModel.currentGlucoseText)
                .foregroundStyle(egvColor)
                .strikethrough(viewModel.isGlucoseStale)
                .font(.headline)
                .bold()
            if let currentTrendImageName = viewModel.currentTrendImageName {
                Image(systemName: currentTrendImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(egvColor)
                    .frame(maxWidth: 15)
                    .offset(.init(width: 0.0, height: -7.0))
                    .accessibilityLabel(Text(currentTrendImageName))
            }
        }
    }

    var egvColor: Color {
        colorScheme == .dark ? viewModel.egvValueColor : .primary
    }
}

// TODO: fails to render and breaks other previews afer failure
/*
struct CurrentBGView_Previews: PreviewProvider {
    static var previews: some View {
        let latestGlucose = NewGlucoseSample.placeholder()
        let viewModel = WidgetViewModel(timelineEntryDate: Date(), latestGlucose: latestGlucose, lastGlucoseChange: 3, isLastEntry: true, glucoseDisplayUnits: .gramsPerUnit)
        LatestGlucoseCircularView(viewModel: viewModel)
    }
}
*/
