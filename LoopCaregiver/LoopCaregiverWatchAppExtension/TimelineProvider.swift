//
//  TimelineProvider.swift
//  LoopCaregiverWatchAppExtension
//
//  Created by Bill Gestrich on 12/18/23.
//

import Foundation
import LoopCaregiverKit
import LoopKit
import SwiftUI
import WidgetKit

class TimelineProvider: AppIntentTimelineProvider {
    /// Shows the first time widget appears on watchface and when redacted
    func placeholder(in context: Context) -> SimpleEntry {
        let composer = ServiceComposerProduction()
        return SimpleEntry(
            looper: nil,
            currentGlucoseSample: nil,
            lastGlucoseChange: nil,
            date: Date(),
            entryIndex: 0,
            isLastEntry: true,
            glucoseDisplayUnits: composer.settings.glucoseDisplayUnits
        )
    }

    /// Used to recommend Looper configurations on Watch only since WatchOS
    /// does not offer a dedicated interface for configurations.
    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        var result: [AppIntentRecommendation<ConfigurationAppIntent>] = []
        let composer = ServiceComposerProduction()
        do {
            let availableLoopers = try composer.accountServiceManager.getLoopers()
            result = availableLoopers.compactMap({ looper in
                let appIntent = ConfigurationAppIntent(looperID: looper.id, name: looper.name)
                guard let name = appIntent.name else {return nil}
                return AppIntentRecommendation(intent: appIntent, description: name)
            })
        } catch {
            print(error)
        }

        return result
    }

    /// Shows when widget is in the gallery and other "transient" times per docs.
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // Docs suggest returning quickly when context.isPreview is true so we use fake data
        let composer = ServiceComposerProduction()
        // TODO: Do I need this Looper? Maybe this async call is causing issues?
        let looper = try? composer.accountServiceManager.getLoopers().first(where: { $0.id == configuration.looperID })
        return SimpleEntry(looper: looper, currentGlucoseSample: .placeholder(), lastGlucoseChange: 10, date: Date(), entryIndex: 0, isLastEntry: true, glucoseDisplayUnits: composer.settings.glucoseDisplayUnits)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let composer = ServiceComposerProduction()
        let entry = await getEntry(composer: composer, configuration: configuration)

        var entries = [SimpleEntry]()
        let nowDate = Date()

        var nextRequestDate: Date = nowDate.addingTimeInterval(60 * 5) // Default interval
        if let nextExpectedGlucoseDate = entry.nextExpectedGlucoseDate(), nextExpectedGlucoseDate > nowDate {
            nextRequestDate = nextExpectedGlucoseDate.addingTimeInterval(60 * 1) // Extra minute to allow time for upload.
        }

        let indexCount = 60
        for index in 0..<indexCount {
            let isLastEntry = index == (indexCount - 1)
            let futureEntry = SimpleEntry(looper: entry.looper, currentGlucoseSample: entry.currentGlucoseSample,
                                          lastGlucoseChange: entry.lastGlucoseChange,
                                          date: nowDate.addingTimeInterval(60 * TimeInterval(index)),
                                          entryIndex: index,
                                          isLastEntry: isLastEntry,
                                          glucoseDisplayUnits: composer.settings.glucoseDisplayUnits)
            entries.append(futureEntry)
        }
        return Timeline(entries: entries, policy: .after(nextRequestDate))
    }
    
    /*
    func getEntry(composer: ServiceComposer, configuration: ConfigurationAppIntent) async -> SimpleEntry {
        return await withCheckedContinuation { continuation in
            Task {
                let looper: Looper?
                do {
                    let allLoopers = try composer.accountServiceManager.getLoopers()
                    
                    guard let looper = allLoopers.first(where: { $0.id == configuration.looperID }) else {
                        continuation.resume(returning: .placeHolderEntry(looper: nil, glucoseDisplayUnits: composer.settings.glucoseDisplayUnits))
                        return
                    }
                    
                    let nightscoutDataSource = NightscoutDataSource(looper: looper, settings: composer.settings)
                    let sortedSamples = try await nightscoutDataSource.fetchRecentGlucoseSamples().sorted(by: { $0.date < $1.date })
                    let latestGlucoseSample = sortedSamples.last
                    let glucoseChange = sortedSamples.getLastGlucoseChange(displayUnits: composer.settings.glucoseDisplayUnits)
                    
                    continuation.resume(returning: SimpleEntry(looper: looper, currentGlucoseSample: latestGlucoseSample, lastGlucoseChange: glucoseChange, date: Date(), entryIndex: 0, isLastEntry: true, glucoseDisplayUnits: composer.settings.glucoseDisplayUnits))
                } catch {
                    continuation.resume(returning: .placeHolderEntry(looper: looper, glucoseDisplayUnits: composer.settings.glucoseDisplayUnits))
                }
            }
        }
    }
    
     */
    
    // TODO: I still needed this wrapper
    // Consider using @MainActor on async version and calling it directly
    /*
    private func getEntry(composer: ServiceComposer, configuration: ConfigurationAppIntent) async -> SimpleEntry {
        return await withCheckedContinuation { continuation in
            Task {
                let entry = await getEntryAsync(composer: composer, configuration: configuration)
                continuation.resume(returning: entry)
            }
        }
    }
     */
    
    // Having issues when using this method without `withCheckedContinuation`.
    // It causes issues with the configuration view and possibly the timeline.
    // Need to research this more.
    @MainActor
     private func getEntry(composer: ServiceComposer, configuration: ConfigurationAppIntent) async -> SimpleEntry {
         let looper: Looper
         let glucoseDisplayUnits = composer.settings.glucoseDisplayUnits
         do {
             looper = try await getLooper(composer: composer, configuration: configuration)
         } catch {
             return .placeHolderEntry(looper: nil, glucoseDisplayUnits: glucoseDisplayUnits)
         }

         do {
             let nightscoutDataSource = NightscoutDataSource(looper: looper, settings: composer.settings)
             let sortedSamples = try await nightscoutDataSource.fetchRecentGlucoseSamples().sorted(by: { $0.date < $1.date })
             let latestGlucoseSample = sortedSamples.last
             let glucoseChange = sortedSamples.getLastGlucoseChange(displayUnits: composer.settings.glucoseDisplayUnits)

             return SimpleEntry(
                 looper: looper,
                 currentGlucoseSample: latestGlucoseSample,
                 lastGlucoseChange: glucoseChange,
                 date: Date(),
                 entryIndex: 0,
                 isLastEntry: true,
                 glucoseDisplayUnits: composer.settings.glucoseDisplayUnits
             )
         } catch {
             return .placeHolderEntry(looper: looper, glucoseDisplayUnits: glucoseDisplayUnits)
         }
     }

    func getLooper(composer: ServiceComposer, configuration: ConfigurationAppIntent) async throws -> Looper {
        let loopers = try composer.accountServiceManager.getLoopers()
        guard let looper = loopers.first(where: { $0.id == configuration.looperID }) else {
            throw TimelineProviderError.missingLooper
        }

        return looper
    }

    private enum TimelineProviderError: Error {
        case missingLooper
    }
}
