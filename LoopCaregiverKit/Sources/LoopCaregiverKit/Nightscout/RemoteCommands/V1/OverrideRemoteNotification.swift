//
//  OverrideRemoteNotification.swift
//  LoopCaregiverKit
//
//  Created by Bill Gestrich on 2/25/23.
//

import Foundation

public struct OverrideRemoteNotification: RemoteNotification, Codable {
    public let name: String
    public let durationInMinutes: Double?
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let enteredBy: String?

    enum CodingKeys: String, CodingKey {
        case name = "override-name"
        case remoteAddress = "remote-address"
        case durationInMinutes = "override-duration-minutes"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case enteredBy = "entered-by"
    }

    public func durationTime() -> TimeInterval? {
        guard let durationInMinutes else {
            return nil
        }
        return TimeInterval(rawValue: durationInMinutes * 60)
    }

    public func toRemoteAction() -> Action {
        let action = OverrideAction(name: name, durationTime: durationTime(), remoteAddress: remoteAddress)
        return .temporaryScheduleOverride(action)
    }

    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["override-name"] != nil
    }
}
