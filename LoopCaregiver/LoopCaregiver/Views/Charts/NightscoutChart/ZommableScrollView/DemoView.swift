//
//  DemoView.swift
//  ScrollViewDemo
//
//  Created by Bill Gestrich on 8/11/23.
//

import Charts
import Combine
import SwiftUI

struct DemoView: View {
    @State private var visibleFrameValues = 6
    @State private var totalGraphValues = 100

    @State private var actionSubject = PassthroughSubject<Action, Never>()

    enum Action: Equatable {
        case chartDoubleTap(CGPoint)
        case zoomInTapped
        case zoomOutTapped
        case scrollLeft
        case scrollCenter
        case scrollRight
    }

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Spacer(minLength: 1)
                    Spacer(minLength: 10)
                    chartView

                    Spacer(minLength: 10)
                }
            }
            HStack {
                Button("-") {
                    actionSubject.send(.zoomOutTapped)
                }
                .buttonStyle(.borderedProminent)
                Button("+") {
                    actionSubject.send(.zoomInTapped)
                }
                .buttonStyle(.borderedProminent)
            }
            HStack {
                Button("Left") {
                    actionSubject.send(.scrollLeft)
                }
                .buttonStyle(.borderedProminent)
                Button("Center") {
                    actionSubject.send(.scrollCenter)
                }
                .buttonStyle(.borderedProminent)
                Button("Right") {
                    actionSubject.send(.scrollRight)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }// .padding(.all)
    }

    var chartView: some View {
        GeometryReader { scrollViewGeometry in
            ZoomableScrollView { proxy in
                Chart {
                    ForEach(allShapes()) { shape in
                        PointMark(
                            x: .value("X", shape.xPos),
                            y: .value("Y", shape.yPos)
                        )
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: totalGraphValues))
                }
                // .chartYAxis(.hidden)
                .chartOverlay { chartProxy in
                    GeometryReader { chartGeometry in
                        ZStack(alignment: .top) {
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .accessibilityAddTraits(.isButton)
                                .onTapGesture(count: 2) { tapLocation in
                                    actionSubject.send(.chartDoubleTap(tapLocation))
                                }
                                .onTapGesture(count: 1) { _ in
                                }
                                .onReceive(actionSubject) { action in
                                    switch action {
                                    case .chartDoubleTap(let tapLocation):
                                        let zoomRequest = ContentViewZoomRequest(
                                            zoomType: .zoomIn,
                                            tapLocation: tapLocation,
                                            scrollViewSize: scrollViewGeometry.size,
                                            chartSize: chartGeometry.size,
                                            plotAreaSize: chartProxy.plotAreaSize
                                        )
                                        zoom(zoomRequest: zoomRequest, viewProxy: proxy)
                                    case .zoomInTapped:
                                        let zoomRequest = ContentViewZoomRequest(
                                            zoomType: .zoomIn,
                                            tapLocation: nil,
                                            scrollViewSize: scrollViewGeometry.size,
                                            chartSize: chartGeometry.size,
                                            plotAreaSize: chartProxy.plotAreaSize
                                        )
                                        zoom(zoomRequest: zoomRequest, viewProxy: proxy)
                                    case .zoomOutTapped:
                                        let zoomRequest = ContentViewZoomRequest(
                                            zoomType: .zoomOut,
                                            tapLocation: nil,
                                            scrollViewSize: scrollViewGeometry.size,
                                            chartSize: chartGeometry.size,
                                            plotAreaSize: chartProxy.plotAreaSize
                                        )
                                        zoom(zoomRequest: zoomRequest, viewProxy: proxy)
                                    case .scrollLeft:
                                        proxy.scrollLeading()
                                    case .scrollCenter:
                                        proxy.scrollCenter()
                                    case .scrollRight:
                                        proxy.scrollTrailing()
                                    }
                                }
                                .onAppear {
                                    let zoomRequest = ContentViewZoomRequest(
                                        zoomType: .zoomNone,
                                        tapLocation: nil,
                                        scrollViewSize: scrollViewGeometry.size,
                                        chartSize: chartGeometry.size,
                                        plotAreaSize: chartProxy.plotAreaSize
                                    )
                                    zoom(zoomRequest: zoomRequest, viewProxy: proxy)
                                }
                        }
                    }
                }
            }
        }
    }

    func allShapes() -> [Shape] {
        var toRet = [Shape]()
        for val in 1...totalGraphValues {
            toRet.append(Shape(xPos: Double(val), yPos: Double(totalGraphValues / 2)))
        }

        return toRet
    }

    var zoomLevel: Double {
        return CGFloat(totalGraphValues) / CGFloat(visibleFrameValues)
    }

    func zoom(zoomRequest: ContentViewZoomRequest, viewProxy: CustomViewProxy) {
        let frameAddition: Int
        switch zoomRequest.zoomType {
        case .zoomIn:
            frameAddition = -1
        case .zoomOut:
            frameAddition = 1
        case .zoomNone:
            frameAddition = 0
        }
        let updatedFrames = visibleFrameValues + frameAddition
        guard updatedFrames >= 1 else {
            return
        }

        visibleFrameValues = updatedFrames

        let chartAxisWidth = zoomRequest.chartSize.width - zoomRequest.plotAreaSize.width
        let updatedFocusedContentFrameWidth = (zoomRequest.scrollViewSize.width * zoomLevel) - chartAxisWidth
        let updatedFocusedContentFrame = CGRect(
            x: 0,
            y: 0,
            width: updatedFocusedContentFrameWidth,
            height: zoomRequest.scrollViewSize.height
        )

        if let tapLocation = zoomRequest.tapLocation {
            let request = ZoomScrollRequest(
                scrollType: .contentPoint(tapLocation),
                updatedFocusedContentFrame: updatedFocusedContentFrame,
                zoomAmount: zoomLevel
            )
            viewProxy.handleZoomScrollRequest(request)
        } else {
            let request = ZoomScrollRequest(
                scrollType: .scrollViewCenter,
                updatedFocusedContentFrame: updatedFocusedContentFrame,
                zoomAmount: zoomLevel
            )
            viewProxy.handleZoomScrollRequest(request)
        }
    }

    struct Shape: Identifiable {
        var xPos: Double
        var yPos: Double
        var id = UUID()
    }
}

struct ContentViewZoomRequest {
    let zoomType: ZoomType
    let tapLocation: CGPoint?
    let scrollViewSize: CGSize
    let chartSize: CGSize
    let plotAreaSize: CGSize

    enum ZoomType {
        case zoomIn
        case zoomOut
        case zoomNone
    }
}
