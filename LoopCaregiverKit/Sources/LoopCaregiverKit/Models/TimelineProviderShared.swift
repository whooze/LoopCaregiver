//
//  TimelineProviderShared.swift
//
//
//  Created by Bill Gestrich on 6/17/24.
//

import Foundation
import LoopKit
import WidgetKit

public struct TimelineProviderShared {
    var composer: ServiceComposer {
        // Fetched regularly as updates to the UserDefaults will not be detected
        // from other processes. See notes in CaregiverSettings for ideas.
        return ServiceComposerProduction()
    }
    
    public init() {
    }
    
    public func timeline(for looperID: String?) async -> Timeline<GlucoseTimeLineEntry> {
        do {
            let looper = try await getLooper(looperID: looperID)
            return await timeline(for: looper)
        } catch {
            return Timeline.createTimeline(error: error, looper: nil)
        }
    }
    
    public func timeline(for looper: Looper) async -> Timeline<GlucoseTimeLineEntry> {
        do {
            let value = try await getTimeLineValue(composer: composer, looper: looper)
            var entries = [GlucoseTimeLineEntry]()
            let nowDate = Date()
            
            var nextRequestDate: Date = nowDate.addingTimeInterval(60 * 5) // Default interval
            let nextExpectedGlucoseDate = value.nextExpectedGlucoseDate()
            if nextExpectedGlucoseDate > nowDate {
                nextRequestDate = nextExpectedGlucoseDate.addingTimeInterval(60 * 1) // Extra minute to allow time for upload.
            }
            
            // Create future entries with the most recent glucose value.
            // These would be used if there no new entries coming in.
            let indexCount = 60
            for index in 0..<indexCount {
                let futureValue = value.valueWithDate(nowDate.addingTimeInterval(60 * TimeInterval(index)))
                entries.append(.success(futureValue))
            }
            return Timeline(entries: entries, policy: .after(nextRequestDate))
        } catch {
            return Timeline.createTimeline(error: error, looper: looper)
        }
    }
    
    public func placeholder() -> GlucoseTimeLineEntry {
        // Treat the placeholder situation as if we are not ready. This seems like a rare case.
        // We may want the UI side to treat this in a special way i.e. show the widget outline
        // but no data.
        return GlucoseTimeLineEntry(error: TimelineProviderError.notReady, date: Date(), looper: nil)
    }
    
    public func previewsEntry() -> GlucoseTimeLineEntry {
        return GlucoseTimeLineEntry.previewsEntry()
    }

    @MainActor
    private func getTimeLineValue(composer: ServiceComposer, looper: Looper) async throws -> GlucoseTimelineValue {
        let nightscoutDataSource = NightscoutDataSource(looper: looper, settings: composer.settings)
        let remoteServiceManager = RemoteDataServiceManager(remoteDataProvider: nightscoutDataSource)
        await remoteServiceManager.updateData()
        let sortedSamples = remoteServiceManager.glucoseSamples
        let overrideAndStatus = remoteServiceManager.activeOverrideAndStatus()
        let currentProfile = remoteServiceManager.currentProfile
        guard let latestGlucoseSample = sortedSamples.last else {
            throw TimelineProviderError.missingGlucose
        }
        let glucoseChange = sortedSamples.getLastGlucoseChange(displayUnits: composer.settings.glucoseDisplayUnits)
        
        return GlucoseTimelineValue(
            looper: looper,
            glucoseSample: latestGlucoseSample,
            lastGlucoseChange: glucoseChange,
            glucoseDisplayUnits: composer.settings.glucoseDisplayUnits,
            overrideAndStatus: overrideAndStatus,
            recentSamples: sortedSamples,
            currentProfile: currentProfile,
            date: Date()
        )
    }
    
    public func snapshot(for looperID: String?, context: TimelineProviderContext) async -> GlucoseTimeLineEntry {
        do {
            let looper = try await getLooper(looperID: looperID)
            if context.isPreview {
                let fakeGlucoseSample = NewGlucoseSample.previews()
                return GlucoseTimeLineEntry(looper: looper, glucoseSample: fakeGlucoseSample, lastGlucoseChange: 10, glucoseDisplayUnits: composer.settings.glucoseDisplayUnits, overrideAndStatus: nil, recentSamples: [], currentProfile: nil, date: Date())
            } else {
                let value = try await getTimeLineValue(composer: composer, looper: looper)
                return GlucoseTimeLineEntry(value: value)
            }
        } catch {
            return GlucoseTimeLineEntry(error: error, date: Date(), looper: nil)
        }
    }
    
    public func availableLoopers() -> [Looper] {
        do {
            return try composer.accountServiceManager.getLoopers()
        } catch {
            print(error)
            return []
        }
    }
    
    private func getLooper(looperID: String?) async throws -> Looper {
        guard let looperID else {
            throw TimelineProviderError.looperNotConfigured
        }
        let loopers = try composer.accountServiceManager.getLoopers()
        guard let looper = loopers.first(where: { $0.id == looperID }) else {
            throw TimelineProviderError.looperNotFound(looperID)
        }

        return looper
    }
    
    private enum TimelineProviderError: LocalizedError {
        case looperNotFound(String)
        case looperNotConfigured
        case notReady
        case missingGlucose
    
        var errorDescription: String? {
            switch self {
            case .looperNotFound(let looperID):
                return "The looper for this widget was not found (\(looperID)). " + configurationText()
            case .looperNotConfigured:
                return "No looper is configured for this widget. " + configurationText()
            case .notReady:
                return "The widget is not ready to display. Wait a few minutes and try again."
            case .missingGlucose:
                return "Missing glucose"
            }
        }
        
        func configurationText() -> String {
            return "Edit by pressing widget for 2 seconds, then choose your Looper."
        }
    }
}

extension Timeline<GlucoseTimeLineEntry> {
    static func createTimeline(error: Error, looper: Looper?) -> Timeline {
        let nextRequestDate = Date().addingTimeInterval(5 * 60)
        return Timeline(entries: [GlucoseTimeLineEntry(error: error, date: Date(), looper: looper)], policy: .after(nextRequestDate))
    }
}
