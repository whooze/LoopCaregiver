//
//  HomeView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 1/20/24.
//

import Foundation
import LoopCaregiverKit
import SwiftUI
import WidgetKit

struct HomeView: View {
    @ObservedObject var accountService: AccountServiceManager
    @ObservedObject var remoteDataSource: RemoteDataServiceManager
    @ObservedObject var settings: CaregiverSettings
    @ObservedObject var looperService: LooperService
    @State private var viewHasAppeared = false
    var watchService: WatchService
    
    @State private var showCarbView = false
    @State private var showBolusView = false
    @State private var showOverrideView = false
    @State private var showSettingsView = false
    
    @Environment(\.scenePhase)
    var scenePhase
    
    init(looperService: LooperService, accountService: AccountServiceManager, settings: CaregiverSettings, watchService: WatchService) {
        self.looperService = looperService
        self.settings = settings
        self.accountService = accountService
        self.remoteDataSource = looperService.remoteDataSource
        self.watchService = watchService
    }
    
    var body: some View {
        VStack {
            HUDView(looperService: looperService, accountService: accountService, settings: settings)
                .padding([.leading, .trailing])
                .padding([.bottom], 5.0)
                .background(Color.cellBackgroundColor)
            if let recommendedBolus = remoteDataSource.recommendedBolus {
                TitleSubtitleRowView(
                    title: "Recommended Bolus",
                    subtitle: LocalizationUtils.presentableStringFromBolusAmount(recommendedBolus) + " U"
                )
                .padding([.bottom, .trailing], 5.0)
            }
            ChartsListView(
                looperService: looperService,
                remoteDataSource: remoteDataSource,
                settings: settings
            )
            .padding([.leading, .trailing], 5.0)
            BottomBarView(
                showCarbView: $showCarbView,
                showBolusView: $showBolusView,
                showOverrideView: $showOverrideView,
                showSettingsView: $showSettingsView,
                remoteDataSource: remoteDataSource
            )
        }
        .overlay {
            if !disclaimerValid() {
                disclaimerOverlay()
            }
        }
        .ignoresSafeArea(.keyboard) // Avoid keyboard bounce when popping back from sheets
        .sheet(isPresented: $showCarbView) {
            CarbInputView(looperService: looperService, settings: settings, showSheetView: $showCarbView)
        }
        .sheet(isPresented: $showBolusView) {
            BolusInputView(
                looperService: looperService,
                settings: settings,
                remoteDataSource: looperService.remoteDataSource,
                showSheetView: $showBolusView
            )
        }
        .sheet(isPresented: $showOverrideView) {
            NavigationStack {
                OverrideView(delegate: looperService.remoteDataSource) {
                    showOverrideView = false
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showOverrideView = false
                        }, label: {
                            Text("Cancel")
                        })
                    }
                }
                .navigationBarTitle(Text("Custom Preset"), displayMode: .inline)
            }
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView(
                looperService: looperService,
                accountService: accountService,
                settings: settings,
                watchService: watchService,
                showSheetView: $showSettingsView
            )
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if viewHasAppeared {
                    Task {
                        await accountService.selectedLooperService?.remoteDataSource.updateData()
                    }
                } else {
                    viewHasAppeared = true
                }
            }
        }
    }
    
    func disclaimerOverlay() -> some View {
        return ZStack {
            Color.cellBackgroundColor
            DisclaimerView(disclaimerAgreedTo: {
                settings.disclaimerAcceptedDate = Date()
            })
        }
    }
    
    func disclaimerValid() -> Bool {
        guard let disclaimerAcceptedDate = settings.disclaimerAcceptedDate else {
            return false
        }
        
        return disclaimerAcceptedDate > Date().addingTimeInterval(-60 * 60 * 24 * 365)
    }
}

#Preview {
    let composer = ServiceComposerPreviews()
    let looper = composer.accountServiceManager.selectedLooper!
    let looperService = composer.accountServiceManager.createLooperService(
        looper: looper
    )
    return HomeView(looperService: looperService, accountService: composer.accountServiceManager, settings: composer.settings, watchService: composer.watchService)
}
