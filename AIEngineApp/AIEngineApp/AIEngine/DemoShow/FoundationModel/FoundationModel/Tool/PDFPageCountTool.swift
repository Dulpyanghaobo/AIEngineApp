//
//  PDFPageCountTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import FoundationModels

struct PDFPageCountTool: Tool {
    let name = "countPDFPages"
    let description = "Returns how many pages are in a PDF."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        @Guide(description: "PDF file name")
        var fileName: String
    }

    @Generable
    struct Result: PromptRepresentable {
        var pages: Int
    }

    func call(arguments: Arguments) async throws -> Result {
        return Result(pages: 12) // 模拟
    }
}
