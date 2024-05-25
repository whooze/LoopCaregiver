//
//  OverrideCancelRemoteNotification.swift
//  LoopCaregiverKit
//
//  Created by Bill Gestrich on 2/25/23.
//

import Foundation

public struct OverrideCancelRemoteNotification: RemoteNotification, Codable {
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let cancelOverride: String
    public let enteredBy: String?

    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case cancelOverride = "cancel-temporary-override"
        case enteredBy = "entered-by"
    }

    public func toRemoteAction() -> Action {
        let action = OverrideCancelAction(remoteAddress: remoteAddress)
        return .cancelTemporaryOverride(action)
    }

    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["cancel-temporary-override"] != nil
    }
}
