//
//  AIEngineError.swift
//  pdfexportapp
//
//  Created by i564407 on 9/28/25.
//
import Foundation

public enum AIEngineError: Error, LocalizedError {
    case modelNotAvailable
    case generationFailed(underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "The AI model is not available on this device."
        case .generationFailed(let underlyingError):
            return "Failed to generate response: \(underlyingError.localizedDescription)"
        }
    }
}
