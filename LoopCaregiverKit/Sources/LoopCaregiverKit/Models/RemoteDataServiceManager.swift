//
//  RemoteDataServiceManager.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/24/22.
//

import Foundation
import HealthKit
import LoopKit
import NightscoutKit

public class RemoteDataServiceManager: ObservableObject {
    @Published public var currentGlucoseSample: NewGlucoseSample?
    @Published public var glucoseSamples: [NewGlucoseSample] = []
    @Published public var predictedGlucose: [NewGlucoseSample] = []
    @Published public var carbEntries: [CarbCorrectionNightscoutTreatment] = []
    @Published public var bolusEntries: [BolusNightscoutTreatment] = []
    @Published public var basalEntries: [TempBasalNightscoutTreatment] = []
    @Published public var overridePresets: [OverrideTreatment] = []
    @Published public var latestDeviceStatus: DeviceStatus?
    @Published public var recommendedBolus: Double?
    @Published public var currentIOB: IOBStatus?
    @Published public var currentCOB: COBStatus?
    @Published public var currentProfile: ProfileSet?
    @Published public var recentCommands: [RemoteCommand] = []
    @Published public var updating = false
    
    private let remoteDataProvider: RemoteDataServiceProvider
    private var dateUpdateTimer: Timer?
    private var foregroundObserver: NSObjectProtocol?
    
    public init(remoteDataProvider: RemoteDataServiceProvider) {
        self.remoteDataProvider = remoteDataProvider
    }
    
    func monitorForUpdates(updateInterval: TimeInterval = 30.0) {
        Task {
            await self.updateData()
        }
        
        self.dateUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true, block: { [weak self] _ in
            guard let self else { return }
            Task {
                await self.updateData()
            }
        })
    }
    
    @MainActor
    public func updateData() async {
        updating = true
        
        do {
            try await updateGlucoseData() // Not async as we want it to load quickly
            
            try await withThrowingTaskGroup(of: Void.self) { (group: inout ThrowingTaskGroup<Void, Error>) in
                group.addTask(priority: .high) {
                    try await self.updateCarbData()
                }
                
                group.addTask(priority: .high) {
                    try await self.updateBolusData()
                }
                
                group.addTask(priority: .high) {
                    try await self.updateBasalData()
                }
                
                group.addTask(priority: .high) {
                    try await self.updateOverrideData()
                }
                
                group.addTask(priority: .high) {
                    try await self.updateDeviceStatusData()
                }
                
                group.addTask(priority: .high) {
                    try await self.updateRemoteCommandData()
                }
                
                group.addTask(priority: .high) {
                    try await self.updateCurrentProfileData()
                }
                
                try await group.waitForAll()
            }
        } catch {
            print("Error fetching data: \(error)")
        }
        
        updating = false
        self.refreshCalculatedData()
    }
    
    @MainActor
    private func updateGlucoseData()async throws {
        let glucoseSamplesAsync = try await remoteDataProvider.fetchGlucoseSamples()
            .sorted(by: { $0.date < $1.date })
        
        if glucoseSamplesAsync != self.glucoseSamples {
            self.glucoseSamples = glucoseSamplesAsync
        }
        
        if let latestGlucoseSample = glucoseSamplesAsync.last(where: { $0.date <= nowDate() }), latestGlucoseSample != currentGlucoseSample {
            currentGlucoseSample = latestGlucoseSample
        }
    }
    
    @MainActor
    private func updateCarbData()async throws {
        let carbEntries = try await remoteDataProvider.fetchCarbEntries()
        if carbEntries != self.carbEntries {
            self.carbEntries = carbEntries
        }
    }
    
    @MainActor
    private func updateBolusData() async throws {
        let bolusEntries = try await remoteDataProvider.fetchBolusEntries()
        if bolusEntries != self.bolusEntries {
            self.bolusEntries = bolusEntries
        }
    }
    
    @MainActor
    private func updateBasalData() async throws {
        let basalEntries = try await remoteDataProvider.fetchBasalEntries()
        if basalEntries != self.basalEntries {
            self.basalEntries = basalEntries
        }
    }
    
    @MainActor
    private func updateOverrideData() async throws {
        let overridePresets = try await remoteDataProvider.fetchOverridePresets()
        if overridePresets != self.overridePresets {
            self.overridePresets = overridePresets
        }
    }
    
    @MainActor
    private func updateDeviceStatusData() async throws {
        if let deviceStatus = try await remoteDataProvider.fetchLatestDeviceStatus() {
            if latestDeviceStatus?.timestamp != deviceStatus.timestamp {
                self.latestDeviceStatus = deviceStatus
            }
            
            if let iob = deviceStatus.loopStatus?.iob,
               iob != self.currentIOB {
                self.currentIOB = iob
            }
            
            if let cob = deviceStatus.loopStatus?.cob,
               cob != self.currentCOB {
                self.currentCOB = cob
            }
            
            let predictedGlucoseSamples = predictedGlucoseSamples(latestDeviceStatus: deviceStatus)
            if predictedGlucoseSamples != self.predictedGlucose {
                self.predictedGlucose = predictedGlucoseSamples
            }
        }
    }
    
    @MainActor
    private func updateRemoteCommandData() async throws {
        let recentCommands = try await remoteDataProvider.fetchRecentCommands()
        if recentCommands != self.recentCommands {
            self.recentCommands = recentCommands
        }
    }
    
    @MainActor
    private func updateCurrentProfileData() async throws {
        let currentProfile = try await remoteDataProvider.fetchCurrentProfile()
        if currentProfile != self.currentProfile {
            self.currentProfile = currentProfile
        }
    }
    
    @MainActor
    private func refreshCalculatedData() {
        guard let updatedRecomendedBolus = calculateValidRecommendedBolus() else {
            self.recommendedBolus = nil
            return
        }
        
        guard self.recommendedBolus != updatedRecomendedBolus else {
            return
        }
        
        self.recommendedBolus = updatedRecomendedBolus
    }
    
    private func calculateValidRecommendedBolus() -> Double? {
        guard let latestDeviceStatus = self.latestDeviceStatus else {
            return nil
        }
        
        guard let recommendedBolus = latestDeviceStatus.loopStatus?.recommendedBolus else {
            return nil
        }
        
        guard recommendedBolus > 0.0 else {
            return nil
        }
        
        let expired = Date().timeIntervalSince(latestDeviceStatus.timestamp) > 60 * 7
        guard !expired  else {
            return nil
        }
        
        if let latestBolusEntry = bolusEntries.filter({ $0.timestamp < nowDate() }).max(by: { $0.timestamp < $1.timestamp }) {
            if latestBolusEntry.timestamp >= latestDeviceStatus.timestamp {
                // Reject recommended bolus if a bolus occurred afterward.
                return nil
            }
        }
        
        return recommendedBolus
    }
    
    func predictedGlucoseSamples(latestDeviceStatus: DeviceStatus) -> [NewGlucoseSample] {
        guard let loopPrediction = latestDeviceStatus.loopStatus?.predicted else {
            return []
        }
        
        let predictedValues = loopPrediction.values
        var predictedSamples = [NewGlucoseSample]()
        var currDate = loopPrediction.startDate
        let intervalBetweenPredictedValues = 60.0 * 5.0
        for value in predictedValues {
            let predictedSample = NewGlucoseSample(date: currDate,
                                                   quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: Double(value)),
                                                   condition: nil,
                                                   trend: nil,
                                                   trendRate: nil,
                                                   isDisplayOnly: false,
                                                   wasUserEntered: false,
                                                   // TODO: Probably needs to be something unique from NS predicted data
                                                   syncIdentifier: UUID().uuidString)
            
            predictedSamples.append(predictedSample)
            currDate = currDate.addingTimeInterval(intervalBetweenPredictedValues)
        }
        
        return predictedSamples
    }
    
    func nowDate() -> Date {
        return Date()
    }
    
    public func checkAuth() async throws {
        try await remoteDataProvider.checkAuth()
    }
    
    public func deliverCarbs(amountInGrams: Double, absorptionTime: TimeInterval, consumedDate: Date) async throws {
        try await remoteDataProvider.deliverCarbs(amountInGrams: amountInGrams, absorptionTime: absorptionTime, consumedDate: consumedDate)
    }
    
    public func deliverBolus(amountInUnits: Double) async throws {
        try await remoteDataProvider.deliverBolus(amountInUnits: amountInUnits)
    }
    
    public func startOverride(overrideName: String, durationTime: TimeInterval) async throws {
        try await remoteDataProvider.startOverride(overrideName: overrideName, durationTime: durationTime)
    }
    
    public func cancelOverride() async throws {
        try await remoteDataProvider.cancelOverride()
    }
    
    public func activateAutobolus(activate: Bool) async throws {
        try await remoteDataProvider.activateAutobolus(activate: activate)
    }
    
    public func activateClosedLoop(activate: Bool) async throws {
        try await remoteDataProvider.activateClosedLoop(activate: activate)
    }
    
    public func fetchActiveOverrideStatus() async throws -> (override: NightscoutKit.TemporaryScheduleOverride, status: NightscoutKit.OverrideStatus)? {
        let latestDeviceStatus = try await remoteDataProvider.fetchLatestDeviceStatus()
        let currentProfile = try await remoteDataProvider.fetchCurrentProfile()
        return activeOverrideAndStatus(latestDeviceStatus: latestDeviceStatus, currentProfile: currentProfile)
    }
    
    public func activeOverrideAndStatus() -> (override: NightscoutKit.TemporaryScheduleOverride, status: NightscoutKit.OverrideStatus)? {
        return activeOverrideAndStatus(latestDeviceStatus: latestDeviceStatus, currentProfile: currentProfile)
    }
    
    private func activeOverrideAndStatus(latestDeviceStatus: DeviceStatus?, currentProfile: ProfileSet?) -> (override: NightscoutKit.TemporaryScheduleOverride, status: NightscoutKit.OverrideStatus)? {
        /*
         There are 3 sources of the current override from Nightscout
         1. Devicestatus.overrideStatus: Used by NS Plugin (bubble view)
         2. Profile.settings.scheduleOverride: Not sure what used by
         3. Override Entries: Used by NS Ticker Tape
         
         */
        
        // 1. Devicestatus.overrideStatus
        // We would use this except it is not up-to-date when Loop events occur in the background.
        guard let overrideStatus = latestDeviceStatus?.overrideStatus, overrideStatus.active else {
            return nil
        }
        
        if let duration = overrideStatus.duration {
            if overrideStatus.timestamp.addingTimeInterval(duration) <= self.nowDate() {
                return nil
            }
        }
        
        // 2. Profile.settings.scheduleOverride
        // The override is not correct when its duration runs out so we have to check Override Entries too
        guard let override = currentProfile?.settings.scheduleOverride else {
            return nil
        }
        
        // 3. Override Entries
        // We could exclusively use this, except a really old override may
        // fall outside our lookback period (i.e. indefinite override)
        //        if let mostRecentOverrideEntry = overrideEntries.filter({$0.timestamp <= nowDate()})
        //            .sorted(by: {$0.timestamp < $1.timestamp})
        //            .last {
        //            if let endDate = mostRecentOverrideEntry.endDate, endDate <= nowDate() {
        //                //Entry expired - This happens when the OverrideStatus above is out of sync with the uploaded entries.
        //                return nil
        //            }
        //        }
        
        return (override, overrideStatus)
    }
    
    public func activeOverride() -> NightscoutKit.TemporaryScheduleOverride? {
        return activeOverrideAndStatus()?.override
    }
    
    public func deleteAllCommands() async throws {
        try await remoteDataProvider.deleteAllCommands()
    }
}
