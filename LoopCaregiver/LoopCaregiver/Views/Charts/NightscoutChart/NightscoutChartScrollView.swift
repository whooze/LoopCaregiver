//
//  NightscoutChartScrollView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/13/22.
//

import Charts
import Combine
import HealthKit
import LoopCaregiverKit
import LoopCaregiverKitUI
import LoopKit
import SwiftUI

// swiftlint:disable file_length
struct NightscoutChartScrollView: View {
    @ObservedObject var settings: CaregiverSettings
    @ObservedObject var remoteDataSource: RemoteDataServiceManager
    @State private var scrollRequestSubject = PassthroughSubject<ScrollType, Never>()
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    static let timelineLookbackIntervals = [1, 3, 6, 12, 24]
    @AppStorage(UserDefaults.standard.timelineVisibleLookbackHoursKey)
    private var timelineVisibleLookbackHours = 6

    @State private var graphItemsInPopover: [GraphItem]?

    private let configuration = NightscoutChartConfiguration()

    // TODO: Remove Disabled Zoom View Things
    @State private var lastScrollUpdate: Date?
    private let minScale: CGFloat = 0.10
    private let maxScale: CGFloat = 3.0
    @State private var currentScale: CGFloat = 1.0

    @Environment(\.scenePhase)
    private var scenePhase

    func glucoseGraphItems() -> [GraphItem] {
        return remoteDataSource.glucoseSamples.map({ $0.graphItem(displayUnit: settings.glucoseDisplayUnits) })
    }

    func predictionGraphItems() -> [GraphItem] {
        return remoteDataSource.predictedGlucose
            .map({ $0.graphItem(displayUnit: settings.glucoseDisplayUnits) })
            .filter({ $0.displayTime <= Date().addingTimeInterval(Double(timelinePredictionHours) * 60.0 * 60.0 ) })
    }

    func bolusGraphItems() -> [GraphItem] {
        return remoteDataSource.bolusEntries
            .map({ $0.graphItem(egvValues: glucoseGraphItems(), displayUnit: settings.glucoseDisplayUnits) })
    }

    func carbEntryGraphItems() -> [GraphItem] {
        return remoteDataSource.carbEntries
            .map({ $0.graphItem(egvValues: glucoseGraphItems(), displayUnit: settings.glucoseDisplayUnits) })
    }

    func remoteCommandGraphItems() -> [GraphItem] {
        return remoteDataSource.recentCommands
            .compactMap({ $0.graphItem(egvValues: glucoseGraphItems(), displayUnit: settings.glucoseDisplayUnits) })
    }

    var body: some View {
        GeometryReader { containerGeometry in
            ZoomableScrollView { zoomScrollViewProxy in
                chartView
                    .chartOverlay { chartProxy in
                        GeometryReader { chartGeometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .accessibilityAddTraits(.isButton)
                                .onTapGesture(count: 2) { tapLocation in
                                    switch timelineVisibleLookbackHours {
                                    case 6:
                                        updateTimelineHours(1)
                                    default:
                                        updateTimelineHours(6)
                                    }
                                    scrollRequestSubject.send(.contentPoint(tapLocation))
                                }
                                .onTapGesture(count: 1) { tapLocation in
                                    print("x pos: \(tapLocation.x)")
                                    if let (date, glucose) = chartProxy.value(at: tapLocation, as: (Date, Double).self) {
                                        let items = getNearbyGraphItems(date: date, value: glucose, chartProxy: chartProxy)
                                        guard !items.isEmpty else {
                                            return
                                        }
                                        graphItemsInPopover = items
                                    }
                                }
                                .onReceive(scrollRequestSubject) { scrollType in
                                    let lookbackHours = CGFloat(totalGraphHours - timelinePredictionHours)
                                    let lookBackWidthRatio = lookbackHours / CGFloat(totalGraphHours)
                                    let axisWidth = chartGeometry.size.width - chartProxy.plotAreaSize.width
                                    let graphWithoutYAxisWidth = (containerGeometry.size.width * zoomLevel) - axisWidth
                                    let lookbackWidth = graphWithoutYAxisWidth * lookBackWidthRatio
                                    let focusedContentFrame = CGRect(x: 0, y: 0, width: lookbackWidth, height: containerGeometry.size.height)

                                    let request = ZoomScrollRequest(scrollType: scrollType, updatedFocusedContentFrame: focusedContentFrame, zoomAmount: zoomLevel)
                                    zoomScrollViewProxy.handleZoomScrollRequest(request)
                                }
                                .onChange(of: currentScale, perform: { _ in
//                                    if let lastScrollUpdate, Date().timeIntervalSince(lastScrollUpdate) < 0.1 {
//                                        return
//                                    }
//                                    zoomScrollViewProxy.updateZoomKeepingCenter(newValue)
//                                    let centerPosition = CGPoint(x: chartGeometry.size.width / 2.0, y: 100.0)
//                                    zoomScrollViewProxy.updateZoom(newValue, centerPosition)
//                                    lastScrollUpdate = Date()
//                                    scrollRequestSubject.send(.scrollViewCenter)
                                })
                            // TODO: Remove Disabled Zoom View Things
                            // .modifier(PinchToZoom(minScale: 0.10, maxScale: 3.0, scale: $currentScale))
                        }
                    }
                    // TODO: Prefer leading/trailing of 10.0
                    // but that is causing graph centering
                    // issues
                    .padding(.init(top: 5, leading: 0, bottom: 0, trailing: 0)) // Top to prevent top Y label from clipping
                    .onChange(of: timelineVisibleLookbackHours) { _ in
                        // This is to catch updates to the picker
                        scrollRequestSubject.send(.scrollViewCenter)
                    }
                    .onAppear(perform: {
                        scrollRequestSubject.send(.scrollViewCenter)
                        zoomScrollViewProxy.scrollTrailing()
                    })
                    .onChange(of: scenePhase) { newPhase in
                        if newPhase == .active {
                            zoomScrollViewProxy.scrollTrailing()
                        }
                    }
            }
        }
        .popover(item: $graphItemsInPopover) { graphItemsInPopover in
            graphItemsPopoverView(graphItemsInPopover: graphItemsInPopover)
        }
    }

    var chartView: some View {
        Chart {
            ForEach(glucoseGraphItems()) {
                PointMark(
                    x: .value("Time", $0.displayTime),
                    y: .value("Reading", $0.value)
                )
                .foregroundStyle(by: .value("Reading", $0.colorType))
                .symbol(
                    FilledCircle()
                )
            }
            if settings.timelinePredictionEnabled {
                ForEach(predictionGraphItems()) {
                    LineMark(
                        x: .value("Time", $0.displayTime),
                        y: .value("Reading", $0.value)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [7.0, 3.0]))
                    .foregroundStyle(Color(uiColor: .magenta.withAlphaComponent(0.5)))
                }
            }
            ForEach(bolusGraphItems()) { graphItem in
                PointMark(
                    x: .value("Time", graphItem.displayTime),
                    y: .value("Reading", graphItem.value)
                )
                .foregroundStyle(by: .value("Reading", ColorType.clear))
                .annotation(position: .overlay, alignment: .center, spacing: 0) {
                    return TreatmentAnnotationView(graphItem: graphItem)
                }
            }
            ForEach(carbEntryGraphItems()) { graphItem in
                PointMark(
                    x: .value("Time", graphItem.displayTime),
                    y: .value("Reading", graphItem.value)
                )
                .foregroundStyle(by: .value("Reading", ColorType.clear))
                .annotation(position: .overlay, alignment: .center, spacing: 0) {
                    return TreatmentAnnotationView(graphItem: graphItem)
                }
            }
            ForEach(remoteCommandGraphItems()) { graphItem in
                PointMark(
                    x: .value("Time", graphItem.displayTime),
                    y: .value("Reading", graphItem.value)
                )
                .foregroundStyle(by: .value("Reading", ColorType.clear))
                .annotation(position: .overlay, alignment: .center, spacing: 0) {
                    return TreatmentAnnotationView(graphItem: graphItem)
                }
            }
        }
        // Make sure the domain values line up with what is in foregroundStyle above.
        .chartForegroundStyleScale(domain: ColorType.membersAsRange(), range: ColorType.allCases.map({ $0.color }), type: .none)
        .chartXScale(domain: chartXRange())
        .chartYScale(domain: chartYRange())
        .chartXAxis {
            AxisMarks(position: .bottom, values: AxisMarkValues.automatic(desiredCount: totalAxisMarks, roundLowerBound: false, roundUpperBound: false)) { date in
                if let date = date.as(Date.self) {
                    AxisValueLabel(format: xAxisLabelFormatStyle(for: date))
                } else {
                    AxisValueLabel(format: xAxisLabelFormatStyle(for: Date()))
                }
                AxisGridLine(centered: true)
            }
        }
//        .chartYAxis(.hidden)
    }

    func graphItemsPopoverView(graphItemsInPopover: [GraphItem]) -> some View {
        NavigationStack {
            List {
                ForEach(graphItemsInPopover) { item in
                    switch item.type {
                    case .bolus, .carb:
                        VStack {
                            HStack {
                                Text(item.displayTime, style: .time)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(item.type.presentableName)
                                    Text(item.formattedValue())
                                }
                            }
                            switch item.graphItemState {
                            case .error(let error):
                                Text(error.localizedDescription)
                                    .foregroundColor(.red)
                            default:
                                EmptyView()
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
            }
            .toolbar(content: {
                    Button {
                        self.graphItemsInPopover = nil
                    } label: {
                        Text("Done")
                    }
            })
        }
        .presentationDetents([.medium])
    }

    func updateTimelineHours(_ hours: Int) {
        timelineVisibleLookbackHours = hours
    }

    func getNearbyGraphItems(date: Date, value: Double, chartProxy: ChartProxy) -> [GraphItem] {
        func distanceCalcuator(graphItem: GraphItem, date: Date, value: Double) -> Double {
            guard let graphItemDatePosition = chartProxy.position(forX: graphItem.displayTime) else {
                assertionFailure("Unexpected")
                return Double.infinity
            }

            guard let graphItemValuePosition = chartProxy.position(forY: graphItem.value) else {
                assertionFailure("Unexpected")
                return Double.infinity
            }

            guard let tappedDatePosition = chartProxy.position(forX: date) else {
                assertionFailure("Unexpected")
                return Double.infinity
            }

            guard let tappedValuePosition = chartProxy.position(forY: value) else {
                assertionFailure("Unexpected")
                return Double.infinity
            }

            return hypot(tappedDatePosition - graphItemDatePosition, tappedValuePosition - graphItemValuePosition)
        }

        let tappableGraphItems = allGraphItems().filter({ graphItem in
            switch graphItem.type {
            case .bolus, .carb:
                return true
            default:
                return false
            }
        })

        let sortedItems = tappableGraphItems.sorted(by: { item1, item2 in
            item1.displayTime < item2.displayTime
        }).filter({ distanceCalcuator(graphItem: $0, date: date, value: value) < 20 })

        if sortedItems.count <= 5 {
            return sortedItems
        } else {
            return Array(sortedItems[0...4])
        }
    }

    func allGraphItems() -> [GraphItem] {
        return remoteCommandGraphItems() + carbEntryGraphItems() + bolusGraphItems() + predictionGraphItems() + glucoseGraphItems()
    }

    func chartXRange() -> ClosedRange<Date> {
        let maxXDate = Date().addingTimeInterval(60 * 60 * TimeInterval(timelinePredictionHours))
        let minXDate = Date().addingTimeInterval(-60 * 60 * TimeInterval(configuration.totalLookbackhours))
        return minXDate...maxXDate
    }

    var zoomLevel: Double {
        return CGFloat(totalGraphHours) / CGFloat(visibleFrameHours)
    }

    var timelinePredictionHours: Int {
        guard settings.timelinePredictionEnabled else {
            return 0
        }

        return min(6, timelineVisibleLookbackHours)
    }

    var totalGraphHours: Int {
        return configuration.totalLookbackhours + timelinePredictionHours
    }

    var visibleFrameHours: Int {
        return timelineVisibleLookbackHours + timelinePredictionHours
    }

    func chartYRange() -> ClosedRange<Double> {
        return chartYBase()...chartYTop()
    }

    func chartYBase() -> Double {
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0).doubleValue(for: settings.glucoseDisplayUnits)
    }

    func chartYTop() -> Double {
        guard let maxGraphYValue = maxValueOfAllGraphItems() else {
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400).doubleValue(for: settings.glucoseDisplayUnits)
        }

        if maxGraphYValue >= 300 {
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400).doubleValue(for: settings.glucoseDisplayUnits)
        } else if maxGraphYValue >= 200 {
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 300).doubleValue(for: settings.glucoseDisplayUnits)
        } else {
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200).doubleValue(for: settings.glucoseDisplayUnits)
        }
    }

    func maxValueOfAllGraphItems() -> Double? {
        let maxBGY = self.glucoseGraphItems().max(by: { $0.value < $1.value })?.quantity.doubleValue(for: .milligramsPerDeciliter)
        var maxPredictedY: Double?
        if settings.timelinePredictionEnabled {
            maxPredictedY = self.predictionGraphItems().max(by: { $0.value < $1.value })?.quantity.doubleValue(for: .milligramsPerDeciliter)
        }

        if let maxBGY, let maxPredictedY {
            return max(maxBGY, maxPredictedY)
        } else if let maxBGY {
            return maxBGY
        } else if let maxPredictedY {
            return maxPredictedY
        } else {
            return nil
        }
    }

    func formatGlucoseQuantity(_ quantity: HKQuantity) -> Double {
        return quantity.doubleValue(for: settings.glucoseDisplayUnits)
    }

    private var xAxisStride: Calendar.Component {
            return .minute
    }

     // How many minutes to skip (i.e. 1 is show every hour)
    private var xAxisStrideCount: Int {
        let visibleFrameMinutes = visibleFrameHours * 60
        return visibleFrameMinutes / 6
    }

    private var maxVisibleXLabels: Int {
        return 5
    }

    private var totalAxisMarks: Int {
        return totalGraphHours / visibleFrameHours * maxVisibleXLabels
    }

    private func xAxisLabelFormatStyle(for date: Date) -> Date.FormatStyle {
        switch visibleFrameHours {
        case 0..<2:
            return .dateTime.hour().minute()
        case 2..<4:
            return .dateTime.hour().minute()
        case 4..<6:
            return .dateTime.hour().minute()
        case 6..<12:
            return .dateTime.hour().minute()
        case 12..<24:
            return .dateTime.hour().minute()
        case 24...:
            return .dateTime.hour().minute()
        default:
            return .dateTime.hour().minute()
        }
    }
}

enum GraphItemType {
    case egv
    case predictedBG
    case bolus(Double)
    case carb(Int)

    var presentableName: String {
        switch self {
        case .egv:
            return "Glucose"
        case .predictedBG:
            return "Predicted Glucose"
        case .bolus:
            return "Bolus"
        case .carb:
            return "Carbs"
        }
    }
}

enum GraphItemState {
    case success
    case pending
    case error(LocalizedError)
}

// Required to use [GraphItem] to control popover visibility
extension [GraphItem]: Identifiable {
    public var id: String {
        var combinedUUID = ""
        for item in self {
            combinedUUID.append(item.id.uuidString)
        }
        return combinedUUID
    }
}

extension ColorType: Plottable {
    public var primitivePlottable: Int {
        return self.rawValue
    }

    public typealias PrimitivePlottable = Int

    public init?(primitivePlottable: Int) {
        self.init(rawValue: primitivePlottable)
    }
}

func interpolateEGVValue(egvs: [GraphItem], atDate date: Date ) -> Double {
    switch egvs.count {
    case 0:
        return 0
    case 1:
        return egvs[0].value
    default:
        let priorEGVs = egvs.filter({ $0.displayTime < date })
        guard let greatestPriorEGV = priorEGVs.last else {
            // All after, use first
            return egvs.first!.value
        }

        let laterEGVs = egvs.filter({ $0.displayTime > date })
        guard let leastFollowingEGV = laterEGVs.first else {
            // All prior, use last
            return egvs.last!.value
        }

        return interpolateYValueInRange(yRange: (y1: greatestPriorEGV.value, y2: leastFollowingEGV.value), referenceXRange: (x1: greatestPriorEGV.displayTime, x2: leastFollowingEGV.displayTime), referenceXValue: date)
    }
}

// Given a known value x in a range (x1, x2), interpolate value y, in range (y1, y2)
func interpolateYValueInRange(yRange: (y1: Double, y2: Double), referenceXRange: (x1: Date, x2: Date), referenceXValue: Date) -> Double {
    let referenceRangeDistance = referenceXRange.x2.timeIntervalSince1970 - referenceXRange.x1.timeIntervalSince1970
    let lowerRangeToValueDifference = referenceXValue.timeIntervalSince1970 - referenceXRange.x1.timeIntervalSince1970
    let scaleFactor = lowerRangeToValueDifference / referenceRangeDistance

    let rangeDifference = abs(yRange.y1 - yRange.y2)
    return yRange.y1 + (rangeDifference * scaleFactor)
}

struct NightscoutChartConfiguration {
    let totalLookbackhours: Int = 24
    let graphTag = 1000
}
// swiftlint:enable file_length
