//
//  Image+Resources.swift
//
//
//  Created by Bill Gestrich on 8/4/24.
//

import Foundation
import SwiftUI

extension Image {
    public static var workout: Image {
        return Image("workout", bundle: Bundle.module)
    }
    
    public static var workoutSelected: Image {
        return Image("workout-selected", bundle: Bundle.module)
    }
}

