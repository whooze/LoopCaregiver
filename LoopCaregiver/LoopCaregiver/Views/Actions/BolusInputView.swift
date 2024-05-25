//
//  BolusInputView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/13/22.
//

import LocalAuthentication
import LoopCaregiverKit
import LoopKitUI
import SwiftUI

struct BolusInputView: View {
    let looperService: LooperService
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @ObservedObject var remoteDataSource: RemoteDataServiceManager
    @Binding var showSheetView: Bool

    @State private var bolusAmount: String = ""
    @State private var duration: String = ""
    @State private var submissionInProgress = false
    @State private var isPresentingConfirm = false
    @State private var errorText: String?
    @State private var nowDate = Date()
    @FocusState private var bolusInputViewIsFocused: Bool

    private let unitFrameWidth: CGFloat = 20.0

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    bolusEntryForm
                    if let errorText {
                        Text(errorText)
                            .foregroundColor(.critical)
                            .padding()
                    }
                    if let deviceDate = remoteDataSource.latestDeviceStatus?.timestamp, remoteDataSource.recommendedBolus != nil {
                        let interval = nowDate.timeIntervalSince(deviceDate)
                        Text("WARNING: New treatments may have occurred since the last recommended bolus was calculated \(LocalizationUtils.presentableMinutesFormat(timeInterval: interval)) ago.")
                            .font(.callout)
                            .foregroundColor(.red)
                            .padding()
                        Spacer()
                    }
                    Button("Deliver") {
                        deliverButtonTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(disableForm())
                    .padding()
                    .confirmationDialog("Are you sure?",
                                        isPresented: $isPresentingConfirm) {
                        Button("Deliver \(bolusAmount) of insulin to \(looperService.looper.name)?", role: .none) {
                            deliverConfirmationButtonTapped()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                .disabled(submissionInProgress)
                .onReceive(timer) { _ in
                    nowDate = Date()
                }
                if submissionInProgress {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        self.showSheetView = false
                    }, label: {
                        Text("Cancel")
                    })
                }
            }
            .navigationBarTitle(Text("Bolus"), displayMode: .inline)
        }
    }

    var bolusEntryForm: some View {
        Form {
            if let recommendedBolus = remoteDataSource.recommendedBolus {
                LabeledContent {
                    Text(LocalizationUtils.presentableStringFromBolusAmount(recommendedBolus))
                    Text("U")
                        .frame(width: unitFrameWidth)
                } label: {
                    Text("Recommended Bolus")
                }
            }
            LabeledContent {
                TextField(
                    "0",
                    text: $bolusAmount
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($bolusInputViewIsFocused)
                .onAppear(perform: {
                    bolusInputViewIsFocused = true
                    if let recommendedBolus = remoteDataSource.recommendedBolus {
                        bolusAmount = LocalizationUtils.presentableStringFromBolusAmount(recommendedBolus)
                    }
                })
                Text("U")
                    .frame(width: unitFrameWidth)
            } label: {
                Text("Bolus")
            }
        }
    }

    @MainActor
    private func deliverButtonTapped() {
        bolusInputViewIsFocused = false
        do {
            errorText = nil
            try validateForm()
            isPresentingConfirm = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func deliverConfirmationButtonTapped() {
        Task {
            let message = String(format: NSLocalizedString("Authenticate to Bolus", bundle: .main, comment: "The message displayed during a device authentication prompt for bolus specification"))

            guard await authenticationHandler(message) else {
                errorText = "Authentication required"
                return
            }

            submissionInProgress = true
            do {
                try await deliverBolus()
                showSheetView = false
            } catch {
                errorText = error.localizedDescription
            }

            submissionInProgress = false
        }
    }

    private func deliverBolus() async throws {
        let fieldValues = try getBolusFieldValues()
        _ = try await remoteDataSource.deliverBolus(amountInUnits: fieldValues.bolusAmount)
    }

    private func validateForm() throws {
        _ = try getBolusFieldValues()
    }

    private func maxBolusAmount() -> Int {
        return looperService.settings.maxBolusAmount
    }

    private func getBolusFieldValues() throws -> BolusInputViewFormValues {
        guard let bolusAmountInUnits = LocalizationUtils.doubleFromUserInput(bolusAmount),
                bolusAmountInUnits > 0 else {
            throw BolusInputViewError.invalidBolusAmount
        }

        guard bolusAmountInUnits <= Double(maxBolusAmount()) else {
            throw BolusInputViewError.exceedsMaxAllowed(maxAllowed: maxBolusAmount())
        }

        return BolusInputViewFormValues(bolusAmount: bolusAmountInUnits)
    }

    private func disableForm() -> Bool {
        return submissionInProgress || bolusAmount.isEmpty
    }

    var authenticationHandler: (String) async -> Bool = { message in
        return await withCheckedContinuation { continuation in
            LocalAuthentication.deviceOwnerCheck(message) { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

struct BolusInputViewFormValues {
    let bolusAmount: Double
}

enum BolusInputViewError: LocalizedError {
    case invalidBolusAmount
    case exceedsMaxAllowed(maxAllowed: Int)

    var errorDescription: String? {
        switch self {
        case .invalidBolusAmount:
            return "Enter a valid bolus amount."
        case .exceedsMaxAllowed(let maxAllowed):
            let localizedAmount = LocalizationUtils.presentableStringFromBolusAmount(Double(maxAllowed))
            return "Enter a bolus amount up to \(localizedAmount) U. The maximum can be increased in Caregiver Settings."
        }
    }

    func pluralizeHour(count: Int) -> String {
        if count > 1 {
            return "hours"
        } else {
            return "hour"
        }
    }
}

#Preview {
    let composer = ServiceComposerPreviews()
    let looper = composer.accountServiceManager.selectedLooper!
    var showSheetView = true
    let showSheetBinding = Binding<Bool>(get: { showSheetView }, set: { showSheetView = $0 })
    let looperService = composer.accountServiceManager.createLooperService(looper: looper, settings: composer.settings)
    let remoteDataSerivceManager = RemoteDataServiceManager(remoteDataProvider: RemoteDataServiceProviderSimulator())
    return BolusInputView(looperService: looperService, remoteDataSource: remoteDataSerivceManager, showSheetView: showSheetBinding)
}
