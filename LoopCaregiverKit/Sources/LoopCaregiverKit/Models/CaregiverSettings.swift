//
//  CaregiverSettings.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/25/22.
//

import Combine
import Foundation
import HealthKit
import WidgetKit

public class CaregiverSettings: NSObject, ObservableObject {
    @Published public var glucosePreference: GlucoseUnitPrefererence
    @Published public var timelinePredictionEnabled: Bool
    @Published public var experimentalFeaturesUnlocked: Bool
    @Published public var remoteCommands2Enabled: Bool
    @Published public var demoModeEnabled: Bool
    @Published public var disclaimerAcceptedDate: Date?
    @Published public var maxCarbAmount: Int
    @Published public var maxBolusAmount: Int

    public let appGroupsSupported: Bool
    
    private let userDefaults: UserDefaults
    private var observationTokens = [NSObject]()
    private var cancellables = [AnyCancellable]()

    public init(userDefaults: UserDefaults, appGroupsSupported: Bool) {
        self.userDefaults = userDefaults
        self.appGroupsSupported = appGroupsSupported

        // Migrations
        if appGroupsSupported {
            Self.migrateUserDefaultsToAppGroup(userDefaults: userDefaults)
        }

        // Defaults
        self.glucosePreference = userDefaults.glucosePreference
        self.timelinePredictionEnabled = userDefaults.timelinePredictionEnabled
        self.remoteCommands2Enabled = userDefaults.remoteCommands2Enabled
        self.demoModeEnabled = userDefaults.demoModeEnabled
        self.experimentalFeaturesUnlocked = userDefaults.experimentalFeaturesUnlocked
        self.disclaimerAcceptedDate = userDefaults.disclaimerAcceptedDate
        self.maxCarbAmount = userDefaults.maxCarbAmount
        self.maxBolusAmount = userDefaults.maxBolusAmount
        super.init()
        setupBindings()
    }
    
    func setupBindings() {
        bindToUserDefaults(
            publishedProperty: $timelinePredictionEnabled,
            userDefaultsKeyPath: \.timelinePredictionEnabled,
            propertyWrapperKeyPath: \.timelinePredictionEnabled
        )
        
        bindToUserDefaults(
            publishedProperty: $remoteCommands2Enabled,
            userDefaultsKeyPath: \.remoteCommands2Enabled,
            propertyWrapperKeyPath: \.remoteCommands2Enabled
        )
        
        bindToUserDefaults(
            publishedProperty: $demoModeEnabled,
            userDefaultsKeyPath: \.demoModeEnabled,
            propertyWrapperKeyPath: \.demoModeEnabled
        )
        
        bindToUserDefaults(
            publishedProperty: $experimentalFeaturesUnlocked,
            userDefaultsKeyPath: \.experimentalFeaturesUnlocked,
            propertyWrapperKeyPath: \.experimentalFeaturesUnlocked
        )
        
        bindToUserDefaults(
            publishedProperty: $disclaimerAcceptedDate,
            userDefaultsKeyPath: \.disclaimerAcceptedDate,
            propertyWrapperKeyPath: \.disclaimerAcceptedDate
        )
        
        bindToUserDefaults(
            publishedProperty: $maxBolusAmount,
            userDefaultsKeyPath: \.maxBolusAmount,
            propertyWrapperKeyPath: \.maxBolusAmount
        )
        
        bindToUserDefaults(
            publishedProperty: $maxCarbAmount,
            userDefaultsKeyPath: \.maxCarbAmount,
            propertyWrapperKeyPath: \.maxCarbAmount
        )
        
        bindToUserDefaults(
            publishedProperty: $glucosePreference,
            userDefaultsKeyPath: \.glucosePreference,
            propertyWrapperKeyPath: \.glucosePreference
        )
    }

    static func migrateUserDefaultsToAppGroup(userDefaults: UserDefaults) {
        let defaultUserDefaults = UserDefaults.standard
        let didMigrateToAppGroups = "DidMigrateToAppGroups"

        guard !userDefaults.bool(forKey: didMigrateToAppGroups) else {
            return
        }

        for key in defaultUserDefaults.dictionaryRepresentation().keys {
            userDefaults.set(defaultUserDefaults.dictionaryRepresentation()[key], forKey: key)
        }

        userDefaults.set(true, forKey: didMigrateToAppGroups)
        userDefaults.synchronize()
        print("Successfully migrated defaults")
    }
    
    /*
     Creates two way binding between @Published Property and UserDefaults.
     The two types must be the same, including optionality.
     
     A challenge to this pattern is the setup is still spread between:
     
     * Reading from defaults in initializer
     * Create these bindings
     * Key definitions (Strings)
     * Dynamic UserDefault properties to support keypaths
     
     Some Ideas to Improve this...
     It may be preferred to define the defaults inline in the Publisher, like @AppStorage does
     Consider getting rid of the dynamic UserDefault and using key (Strings) directly.
     The method below could always set the default to the property wrapper, if it is ever set to nil in UserDefaults.
     */
    func bindToUserDefaults<T>(
        publishedProperty: any Publisher<T, Never>,
        userDefaultsKeyPath: ReferenceWritableKeyPath<UserDefaults, T>,
        propertyWrapperKeyPath: ReferenceWritableKeyPath<CaregiverSettings, T>
    ) where Published<T>.Publisher.Output == T, Published<T>.Publisher.Output: Equatable {
        self[keyPath: propertyWrapperKeyPath] = self.userDefaults[keyPath: userDefaultsKeyPath]
        
        // Write Property to user defaults
        publishedProperty.sink { [weak self] val in
            guard let self else { return }
            let existingValue = self.userDefaults[keyPath: userDefaultsKeyPath]
            if existingValue != val {
                self.userDefaults[keyPath: userDefaultsKeyPath] = val
                WidgetCenter.shared.reloadAllTimelines()
            }
        }.store(in: &cancellables)
        
        // Write UserDefaults to property wrapper
        // Using KVO allows widgets to detect when UserDefaults change in the app.
        // Per the docs, NSNotification.didChangeNotification
        // does not work for out-of-process updates and KVO is recommended.
        let token = self.userDefaults.observe(userDefaultsKeyPath) { [weak self] _, _ in
            guard let self else { return }
            let existingPropertyValue = self[keyPath: propertyWrapperKeyPath]
            let userDefaultsValue = self.userDefaults[keyPath: userDefaultsKeyPath]
            if existingPropertyValue != userDefaultsValue {
                self[keyPath: propertyWrapperKeyPath] = userDefaultsValue
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        observationTokens.append(token)
    }
}

public extension UserDefaults {
    var glucoseUnitKey: String {
        return "glucoseUnit"
    }

    var timelinePredictionEnabledKey: String {
        return "timelinePredictionEnabled"
    }

    var timelineVisibleLookbackHoursKey: String {
        return "timelineVisibleLookbackHours"
    }

    var remoteCommands2EnabledKey: String {
        return "remoteCommands2Enabled"
    }

    var demoModeEnabledKey: String {
        return "demoModeEnabled"
    }

    var experimentalFeaturesUnlockedKey: String {
        return "experimentalFeaturesUnlocked"
    }

    var disclaimerAcceptedDateKey: String {
        return "disclaimerAcceptedDate"
    }

    var maxCarbAmountKey: String {
        return "maxCarbsAmount"
    }

    var maxBolusAmountKey: String {
        return "maxBolusAmount"
    }
    
    @objc var glucoseUnit: Int {
        get { return integer(forKey: glucoseUnitKey) }
        set { set(newValue, forKey: glucoseUnitKey) }
    }

    @objc dynamic var glucosePreference: GlucoseUnitPrefererence {
        get {
            return GlucoseUnitPrefererence(rawValue: integer(forKey: glucoseUnitKey)) ?? .milligramsPerDeciliter
        }
        set {
            set(newValue.rawValue, forKey: glucoseUnitKey)
        }
    }

    @objc dynamic var timelinePredictionEnabled: Bool {
        get { bool(forKey: timelinePredictionEnabledKey) }
        set { setValue(newValue, forKey: timelinePredictionEnabledKey) }
    }

    @objc dynamic var remoteCommands2Enabled: Bool {
        get { bool(forKey: remoteCommands2EnabledKey) }
        set { setValue(newValue, forKey: remoteCommands2EnabledKey) }
    }

    @objc dynamic var demoModeEnabled: Bool {
        get { bool(forKey: demoModeEnabledKey) }
        set { setValue(newValue, forKey: demoModeEnabledKey) }
    }

    @objc dynamic var experimentalFeaturesUnlocked: Bool {
        get { bool(forKey: experimentalFeaturesUnlockedKey) }
        set { setValue(newValue, forKey: experimentalFeaturesUnlockedKey) }
    }

    @objc dynamic var maxCarbAmount: Int {
        get {
            guard let maxCarbAmount = object(forKey: maxCarbAmountKey) as? Int else {
                return 50
            }
            return maxCarbAmount
        }
        set {
            setValue(newValue, forKey: maxCarbAmountKey)
        }
    }

    @objc dynamic var maxBolusAmount: Int {
        get {
            guard let maxBolus = object(forKey: maxBolusAmountKey) as? Int else {
                return 10
            }
            return maxBolus
        }
        set {
            setValue(newValue, forKey: maxBolusAmountKey)
        }
    }

    @objc dynamic var disclaimerAcceptedDate: Date? {
        get {
            guard let date = object(forKey: disclaimerAcceptedDateKey) as? Date else {
                return nil
            }
            return date
        }
        set {
            setValue(newValue, forKey: disclaimerAcceptedDateKey)
        }
    }
}

@objc
public enum GlucoseUnitPrefererence: Int, Codable, CaseIterable {
    case milligramsPerDeciliter
    case millimolesPerLiter

    public var presentableDescription: String {
        switch self {
        case .milligramsPerDeciliter:
            return "mg/dL"
        case .millimolesPerLiter:
            return "mmol/L"
        }
    }

    public var unit: HKUnit {
        switch self {
        case .milligramsPerDeciliter:
            return .milligramsPerDeciliter
        case .millimolesPerLiter:
            return .millimolesPerLiter
        }
    }
}
