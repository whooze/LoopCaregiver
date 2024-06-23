//
//  TimelineWidgetProvider.swift
//  LoopCaregiverWidgetExtension
//
//  Created by Bill Gestrich on 6/2/23.
//

import CoreData
import Intents
import LoopCaregiverKit
import LoopKit
import WidgetKit

struct TimelineWidgetProvider: IntentTimelineProvider {
    let providerShared = TimelineProviderShared()
    
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<GlucoseTimeLineEntry>) -> Void) {
        Task {
            let timeline = await providerShared.timeline(for: configuration.looper?.identifier)
            completion(timeline)
        }
    }
    
    func placeholder(in context: Context) -> GlucoseTimeLineEntry {
        return providerShared.placeholder()
    }

    /// Shows when widget is in the gallery and other "transient" times per docs.
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (GlucoseTimeLineEntry) -> Void) {
        Task {
            let entry = await providerShared.snapshot(for: configuration.looper?.identifier, context: context)
            completion(entry)
        }
    }
}
