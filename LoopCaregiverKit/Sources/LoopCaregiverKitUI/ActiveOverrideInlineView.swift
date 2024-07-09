//
//  ActiveOverrideInlineView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 7/8/24.
//

import Foundation
import NightscoutKit
import SwiftUI

public struct ActiveOverrideInlineView: View {
    let activeOverride: NightscoutKit.TemporaryScheduleOverride
    let status: NightscoutKit.OverrideStatus
    
    public init(activeOverride: TemporaryScheduleOverride, status: OverrideStatus) {
        self.activeOverride = activeOverride
        self.status = status
    }
    
    public var body: some View {
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
