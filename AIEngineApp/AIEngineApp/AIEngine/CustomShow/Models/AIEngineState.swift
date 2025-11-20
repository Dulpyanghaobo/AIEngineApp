//
//  AIEngineState.swift
//  pdfexportapp
//
//  Created by i564407 on 9/28/25.
//

import Foundation

public enum AIEngineState: Equatable {
    case checkingAvailability
    case available
    case unavailable(reason: String)
}
