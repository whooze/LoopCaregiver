//
//  HUDView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/17/22.
//

import Combine
import HealthKit
import LoopCaregiverKit
import LoopCaregiverKitUI
import LoopKit
import SwiftUI

struct HUDView: View {
    @ObservedObject var hudViewModel: HUDViewModel
    @ObservedObject var nightscoutDataSource: RemoteDataServiceManager
    @ObservedObject private var settings: CaregiverSettings
    @State private var looperPopoverShowing = false

    init(looperService: LooperService, settings: CaregiverSettings) {
        self.hudViewModel = HUDViewModel(
            selectedLooper: looperService.looper,
            accountService: looperService.accountService,
            settings: settings
        )
        self.nightscoutDataSource = looperService.remoteDataSource
        self.settings = settings
    }

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                HStack {
                    Text(
                        nightscoutDataSource.currentGlucoseSample?.presentableStringValue(
                            displayUnits: settings.glucoseDisplayUnits,
                            includeShortUnits: false
                        ) ?? " "
                    )
                        .strikethrough(egvIsOutdated())
                        .font(.largeTitle)
                        .foregroundColor(egvValueColor())
                    if let egv = nightscoutDataSource.currentGlucoseSample {
                        Image(systemName: egv.arrowImageName())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 15.0)
                            .foregroundColor(egvValueColor())
                            .accessibilityLabel(egv.arrowImageName())
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
                Spacer()
                HStack {
                    if nightscoutDataSource.updating {
                        ProgressView()
                            .padding([.trailing], 10.0)
                    }
                    pickerButton
                }
            }.onChange(of: hudViewModel.selectedLooper) { _ in
                looperPopoverShowing = false
            }
            if let (activeOverride, status) = nightscoutDataSource.activeOverrideAndStatus() {
                HStack {
                    Text(activeOverride.presentableDescription())
                        .bold()
                        .font(.subheadline)
                    Spacer()
                    if let endTimeDescription = status.endTimeDescription() {
                        Text(endTimeDescription)
                            .foregroundColor(.gray)
                            .bold()
                            .font(.subheadline)
                    }
                }
            }
        }
    }

   var pickerButton: some View {
        Button {
            looperPopoverShowing = true
        } label: {
            HStack {
                Text(hudViewModel.selectedLooper.name)
                Image(systemName: "person.crop.circle")
                    .accessibilityLabel(Text("select looper"))
            }
        }
        .popover(isPresented: $looperPopoverShowing) {
            NavigationStack {
                Form {
                    Picker("", selection: $hudViewModel.selectedLooper) {
                        ForEach(hudViewModel.loopers()) { looper in
                            Text(looper.name).tag(looper)
                        }
                    }
                    .pickerStyle(.inline)
                }
                .toolbar(content: {
                    ToolbarItem {
                        Button {
                            looperPopoverShowing = false
                        } label: {
                            Text("Done")
                        }
                    }
                })
            }
            .presentationDetents([.medium])
        }
    }

    func egvValueColor() -> Color {
        guard let currentEGV = nightscoutDataSource.currentGlucoseSample else {
            return .white
        }
        return ColorType(quantity: currentEGV.quantity).color
    }

    func egvIsOutdated() -> Bool {
        guard let currentEGV = nightscoutDataSource.currentGlucoseSample else {
            return true
        }
        return Date().timeIntervalSince(currentEGV.date) > 60 * 10
    }

    func lastEGVTimeFormatted() -> String {
        guard let currentEGV = self.nightscoutDataSource.currentGlucoseSample else {
            return ""
        }

        return currentEGV.date.formatted(.dateTime.hour().minute())
    }

    func lastEGVDeltaFormatted() -> String {
        let samples = nightscoutDataSource.glucoseSamples
        guard let lastEGVChange = samples.getLastGlucoseChange(displayUnits: settings.glucoseDisplayUnits) else {
            return ""
        }
        
        return lastEGVChange.formatted(
            .number
                .sign(strategy: .always(includingZero: false))
            .precision(.fractionLength(0...1))
        )
    }

    enum EGVTrend: Int {
        case doubleUp = 1
        case singleUp = 2
        case fortyFiveUp = 3
        case flat = 4
        case fortyFiveDown = 5
        case singleDown = 6
        case doubleDown = 7
        case nonComputable = 8
        case outOfRange = 9
    }
}

class HUDViewModel: ObservableObject {
    @Published var glucoseDisplayUnits: HKUnit
    /*
     TODO: This property both reflects
     the selectedLooper account to the AccountServiceManager
     and the selection state of the HUD view. This may be a problem
     as it can lead to recursive updates since updating the active
     loop user, updates the lastSelectedDate, which sends a new
     selectedLooper to the initializer of this view.
     See note == method of Looper.
     See also the refresh() method of AccountServiceManager which
     may be working around some of this.
     */
    @Published var selectedLooper: Looper {
        didSet {
            do {
                try accountService.updateActiveLoopUser(selectedLooper)
            } catch {
                print(error)
            }
        }
    }
    @ObservedObject var accountService: AccountServiceManager
    private var settings: CaregiverSettings
    private var subscribers: Set<AnyCancellable> = []

    init(selectedLooper: Looper, accountService: AccountServiceManager, settings: CaregiverSettings) {
        self.selectedLooper = selectedLooper
        self.accountService = accountService
        self.settings = settings
        self.glucoseDisplayUnits = self.settings.glucoseDisplayUnits

        // TODO: This is a hack to support: accountService.selectedLooper = looper
        // Move this logic to accountService.
        self.accountService.$selectedLooper.sink { _ in
        } receiveValue: { [weak self] updatedUser in
            if let self, let updatedUser, self.selectedLooper != updatedUser {
                self.selectedLooper = updatedUser
            }
        }.store(in: &subscribers)
    }

    func loopers() -> [Looper] {
        return accountService.loopers
    }

    @objc
    func defaultsChanged(notication: Notification) {
        if self.glucoseDisplayUnits != settings.glucoseDisplayUnits {
            self.glucoseDisplayUnits = settings.glucoseDisplayUnits
        }
    }
}
