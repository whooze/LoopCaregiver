//
//  HomeView.swift
//  LoopCaregiverWatchApp
//
//  Created by Bill Gestrich on 12/18/23.
//

import LoopCaregiverKit
import LoopCaregiverKitUI
import SwiftUI
import WidgetKit

struct HomeView: View {
    @ObservedObject var connectivityManager: WatchService
    @ObservedObject var accountService: AccountServiceManager
    @ObservedObject var remoteDataSource: RemoteDataServiceManager
    @ObservedObject var settings: CaregiverSettings
    @ObservedObject var looperService: LooperService
    @State private var dataUpdating = false
    @Environment(\.scenePhase)
    var scenePhase
    
    init(connectivityManager: WatchService, accountService: AccountServiceManager, looperService: LooperService) {
        self.connectivityManager = connectivityManager
        self.looperService = looperService
        self.settings = accountService.settings
        self.accountService = accountService
        self.remoteDataSource = looperService.remoteDataSource
    }
    
    var body: some View {
        ZStack {
            switch glucoseTimelineEntry {
            case .success(let glucoseTimelineValue):
                GeometryReader { geometryProxy in
                    List {
                        NightscoutChartScrollView(settings: settings, remoteDataSource: remoteDataSource, compactMode: true)
                            .frame(height: geometryProxy.size.height * 0.75)
                            .listRowBackground(Color.clear)
                            .listRowInsets(.none)
                        if let (override, status) = glucoseTimelineValue.treatmentData.overrideAndStatus {
                            NavigationLink {
                                Text("Override Control Coming Soon...")
                            } label: {
                                Label {
                                    if status.active {
                                        Text(override.presentableDescription())
                                    } else {
                                        Text("Overrides")
                                    }
                                } icon: {
                                    workoutImage(isActive: status.active)
                                        .renderingMode(.template)
                                        .foregroundColor(.blue)
                                        .accessibilityLabel(Text("Workout"))
                                }
                            }
                        }
                        NavigationLink {
                            WatchSettingsView(
                                connectivityManager: connectivityManager,
                                accountService: accountService,
                                settings: settings
                            )
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                    .listRowInsets(.none)
                }
            case .failure(let glucoseTimeLineEntryError):
                if !dataUpdating {
                    Text(glucoseTimeLineEntryError.localizedDescription)
                }
            }
            if dataUpdating {
                ProgressView()
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    Task {
                        updateData()
                    }
                }, label: {
                    switch glucoseTimelineEntry {
                    case .success(let glucoseTimelineValue):
                        LatestGlucoseRowView(glucoseValue: glucoseTimelineValue)
                    case .failure:
                        Text("")
                    }
                })
            }
        }
        .onChange(of: scenePhase, { _, _ in
            updateData()
        })
    }
    
    func workoutImage(isActive: Bool) -> Image {
        if overrideIsActive() {
            return Image.workoutSelected
        } else {
            return Image.workout
        }
    }
    
    private func overrideIsActive() -> Bool {
        remoteDataSource.activeOverride() != nil
    }
    
    @MainActor
    private func updateData() {
        dataUpdating = true
        Task {
            await looperService.remoteDataSource.updateData()
            reloadWidget()
            await MainActor.run {
                dataUpdating = false
            }
        }
    }
    
    private var glucoseTimelineEntry: GlucoseTimeLineEntry {
        let sortedSamples = remoteDataSource.glucoseSamples
        guard let latestGlucoseSample = sortedSamples.last else {
            return GlucoseTimeLineEntry(error: WatchViewError.missingGlucose, date: Date(), looper: looperService.looper)
        }
        let treatmentData = CaregiverTreatmentData(
            glucoseDisplayUnits: settings.glucoseDisplayUnits,
            glucoseSamples: sortedSamples,
            predictedGlucose: remoteDataSource.predictedGlucose,
            bolusEntries: remoteDataSource.bolusEntries,
            carbEntries: remoteDataSource.carbEntries,
            recentCommands: remoteDataSource.recentCommands,
            overrideAndStatus: remoteDataSource.activeOverrideAndStatus(),
            currentIOB: remoteDataSource.currentIOB,
            currentCOB: remoteDataSource.currentCOB,
            recommendedBolus: remoteDataSource.recommendedBolus
        )
        let value = GlucoseTimelineValue(
            looper: looperService.looper,
            glucoseSample: latestGlucoseSample,
            treatmentData: treatmentData,
            date: Date()
        )
        return GlucoseTimeLineEntry(value: value)
    }
    
    private enum WatchViewError: LocalizedError {
        case missingGlucose
        
        var errorDescription: String? {
            switch self {
            case .missingGlucose:
                return "Missing glucose"
            }
        }
    }
    
    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    let composer = ServiceComposerPreviews()
    return NavigationStack {
        let looper = composer.accountServiceManager.selectedLooper!
        let looperService = composer.accountServiceManager.createLooperService(
            looper: looper
        )
        HomeView(connectivityManager: composer.watchService, accountService: composer.accountServiceManager, looperService: looperService)
    }
}
