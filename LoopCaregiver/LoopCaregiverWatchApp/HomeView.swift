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
        Group {
            switch glucoseTimelineEntry {
            case .success(let glucoseTimelineValue):
                LatestGlucoseRowView(glucoseValue: glucoseTimelineValue)
                NightscoutChartScrollView(settings: settings, remoteDataSource: remoteDataSource)
                if let override = glucoseTimelineValue.treatmentData.overrideAndStatus?.override {
                    Text(override.presentableDescription())
                        .font(.footnote)
                }
            case .failure(let glucoseTimeLineEntryError):
                Text(glucoseTimeLineEntryError.localizedDescription)
            }
        }
        .navigationTitle(accountService.selectedLooper?.name ?? "?")
        .navigationDestination(for: String.self,
                               destination: { _ in
            WatchSettingsView(
                connectivityManager: connectivityManager,
                accountService: accountService,
                settings: settings
            )
        })
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: "SettingsView") {
                    Image(systemName: "gear")
                        .accessibilityLabel(Text("Settings"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await looperService.remoteDataSource.updateData()
                        reloadWidget()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .accessibilityLabel(Text("Refresh"))
                }
            }
        }
        .onChange(of: scenePhase, { _, _ in
            Task {
                await remoteDataSource.updateData()
                // reloadWidget()
            }
        })
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
            overrideAndStatus: remoteDataSource.activeOverrideAndStatus()
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
