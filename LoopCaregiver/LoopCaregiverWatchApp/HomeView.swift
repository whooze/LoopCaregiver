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

    init(connectivityManager: WatchService, looperService: LooperService) {
        self.connectivityManager = connectivityManager
        self.looperService = looperService
        self.settings = looperService.settings
        self.accountService = looperService.accountService
        self.remoteDataSource = looperService.remoteDataSource
    }

    var body: some View {
        VStack {
            HStack {
                Text(remoteDataSource.currentGlucoseSample?.presentableStringValue(displayUnits: settings.glucoseDisplayUnits, includeShortUnits: false) ?? " ")
                    .strikethrough(egvIsOutdated())
                    .font(.largeTitle)
                    .foregroundColor(egvValueColor())
                if let egv = remoteDataSource.currentGlucoseSample {
                    Image(systemName: egv.arrowImageName())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15.0)
                        .foregroundColor(egvValueColor())
                        .accessibilityLabel(Text(egv.arrowImageName()))
                }
                VStack {
                    Text(lastEGVTimeFormatted())
                        .font(.footnote)
                        .if(egvIsOutdated(), transform: { view in
                            view.foregroundColor(.red)
                        })
                    Text(lastEGVDeltaFormatted())
                        .font(.footnote)
                }
            }
            if let overrideAndStatus = remoteDataSource.activeOverrideAndStatus() {
                Text(overrideAndStatus.override.presentableDescription())
            }
        }
        .navigationTitle(accountService.selectedLooper?.name ?? "Name?")
        .navigationDestination(for: String.self,
                               destination: { _ in
            SettingsView(
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
            }
        })
    }

    func glucoseText() -> String {
        return remoteDataSource.currentGlucoseSample?.presentableStringValue(
            displayUnits: settings.glucoseDisplayUnits,
            includeShortUnits: false
        ) ?? " "
    }

    func lastEGVTimeFormatted() -> String {
        guard let currentEGV = remoteDataSource.currentGlucoseSample else {
            return ""
        }

        return currentEGV.date.formatted(.dateTime.hour().minute())
    }

    func egvIsOutdated() -> Bool {
        guard let currentEGV = remoteDataSource.currentGlucoseSample else {
            return true
        }
        return Date().timeIntervalSince(currentEGV.date) > 60 * 10
    }

    func egvValueColor() -> Color {
        guard let currentEGV = remoteDataSource.currentGlucoseSample else {
            return .white
        }
        return ColorType(quantity: currentEGV.quantity).color
    }

    func lastEGVDeltaFormatted() -> String {
        let samples = remoteDataSource.glucoseSamples
        let displayUnits = settings.glucoseDisplayUnits
        guard let lastEGVChange = samples.getLastGlucoseChange(displayUnits: displayUnits) else {
            return ""
        }
        
        return lastEGVChange.formatted(
            .number
                .sign(strategy: .always(includingZero: false))
            .precision(.fractionLength(0...1))
        )
    }

    func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    let composer = ServiceComposerPreviews()
    return NavigationStack {
        let looper = composer.accountServiceManager.selectedLooper!
        let looperService = composer.accountServiceManager.createLooperService(
            looper: looper,
            settings: composer.settings
        )
        HomeView(connectivityManager: composer.watchService, looperService: looperService)
    }
}
