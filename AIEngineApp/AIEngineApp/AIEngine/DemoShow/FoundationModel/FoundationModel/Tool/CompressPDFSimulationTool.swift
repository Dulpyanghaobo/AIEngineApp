//
//  CompressPDFSimulationTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import FoundationModels


struct CompressPDFSimulationTool: Tool {
    let name = "simulatePDFCompression"
    let description = "Predicts final PDF size after compression."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        @Guide(description: "Original file size in MB", .range(1...100))
        var originalMB: Double
        
        @Guide(description: "Compression level (1=low, 3=high)", .range(1...3))
        var level: Int
    }

    @Generable
    struct Result: PromptRepresentable {
        var estimatedMB: Double
        var note: String
    }

    func call(arguments: Arguments) async throws -> Result {
        let factor = switch arguments.level {
            case 1: 0.8
            case 2: 0.5
            default: 0.3
        }
        let size = arguments.originalMB * factor
        
        return Result(
            estimatedMB: size,
            note: "Compression level \(arguments.level) applied."
        )
    }
}
