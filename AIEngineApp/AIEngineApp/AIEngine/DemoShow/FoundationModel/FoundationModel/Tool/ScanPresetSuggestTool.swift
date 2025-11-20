//
//  ScanPresetSuggestTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//
import FoundationModels


// MARK: - Scan Preset Suggest Tool ----------------------------------------

struct ScanPresetSuggestTool: Tool {
    typealias Arguments = ScanPresetSuggestTool.ArgumentsPayload
    typealias Output    = ScanPresetSuggestTool.ResultPayload
    
    let name = "suggestScanPreset"
    let description = "Suggests a scan preset (dpi, filter, auto-crop) based on document type and environment."
    
    @Generable(description: "Arguments for choosing a scan preset")
    struct ArgumentsPayload: ConvertibleFromGeneratedContent {
        @Guide(description: "Document type: contract, idCard, receipt, taxDocument, other")
        var documentType: String
        
        @Guide(description: "Lighting condition: bright, dim, mixed")
        var lighting: String
        
        @Guide(description: "Whether this is a multi-page document")
        var isMultiPage: Bool
        
        @Guide(description: "Whether the user cares more about file size than quality")
        var prefersSmallerFile: Bool
    }
    
    @Generable(description: "Recommended scan preset")
    struct ResultPayload: PromptRepresentable {
        var presetId: String
        var dpi: Int
        var filter: String
        var autoCropEnabled: Bool
        var multiPageMode: String
        var explanation: String
    }
    
    func call(arguments: ArgumentsPayload) async throws -> ResultPayload {
        let docType = arguments.documentType.lowercased()
        let lighting = arguments.lighting.lowercased()
        
        var dpi = 300
        var filter = "color"
        var autoCrop = true
        
        if docType == "idcard" {
            dpi = 600
            filter = "document-bw"
        } else if docType == "contract" {
            dpi = 300
            filter = "document-bw"
        } else if docType == "receipt" {
            dpi = 300
            filter = "receipt-enhance"
        } else if docType == "taxdocument" {
            dpi = 300
            filter = "document-gray"
        }
        
        // 光线偏暗时，适当提高 dpi / 使用增强滤镜
        if lighting == "dim" {
            dpi = max(dpi, 300)
            if filter == "color" {
                filter = "lowlight-enhance"
            }
        }
        
        // 偏向小文件：降低 dpi，选择更压缩的滤镜
        if arguments.prefersSmallerFile {
            dpi = min(dpi, 300)
            if filter == "document-bw" || filter == "document-gray" {
                // 这类滤镜本身就小，不动
            } else {
                filter = "compressed-color"
            }
        }
        
        let multiPageMode = arguments.isMultiPage ? "continuous" : "single"
        
        let presetId = [
            docType.isEmpty ? "other" : docType,
            lighting,
            arguments.isMultiPage ? "multi" : "single"
        ].joined(separator: "_")
        
        var explanationParts: [String] = []
        explanationParts.append("Document type: \(docType.isEmpty ? "other" : docType).")
        explanationParts.append("Lighting: \(lighting).")
        explanationParts.append("DPI: \(dpi). Filter: \(filter).")
        explanationParts.append("Multi-page mode: \(multiPageMode).")
        if arguments.prefersSmallerFile {
            explanationParts.append("Optimized for smaller file size.")
        } else {
            explanationParts.append("Optimized for clarity.")
        }
        
        return ResultPayload(
            presetId: presetId,
            dpi: dpi,
            filter: filter,
            autoCropEnabled: autoCrop,
            multiPageMode: multiPageMode,
            explanation: explanationParts.joined(separator: " ")
        )
    }
}
