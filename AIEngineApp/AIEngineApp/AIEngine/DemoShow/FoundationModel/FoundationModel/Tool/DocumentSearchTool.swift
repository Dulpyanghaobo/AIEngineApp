//
//  DocumentSearchTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//
import FoundationModels
import Foundation


struct DocumentSearchTool: Tool {
    let name = "searchDocuments"
    let description = "Searches scanned documents in user's library."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        @Guide(description: "Search keyword")
        var keyword: String
    }

    @Generable
    struct Doc: PromptRepresentable {
        var title: String
        var type: String
        var modifiedAt: String
    }

    @Generable
    struct Result: PromptRepresentable {
        var documents: [Doc]
    }

    func call(arguments: Arguments) async throws -> Result {
        let docs = [
            Doc(title: "Tax_2023.pdf", type: "pdf", modifiedAt: "2025-10-22"),
            Doc(title: "ID_Card_Scan.jpg", type: "image", modifiedAt: "2025-10-20"),
            Doc(title: "Bank_Statement.pdf", type: "pdf", modifiedAt: "2025-10-15")
        ]

        let matched = docs.filter {
            $0.title.localizedCaseInsensitiveContains(arguments.keyword)
        }

        return Result(documents: matched)
    }
}
