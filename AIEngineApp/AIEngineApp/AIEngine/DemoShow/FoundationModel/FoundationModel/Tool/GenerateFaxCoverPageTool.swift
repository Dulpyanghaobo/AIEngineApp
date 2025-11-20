//
//  GenerateFaxCoverPageTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import FoundationModels

struct GenerateFaxCoverPageTool: Tool {
    let name = "generateFaxCoverPage"
    let description = "Generates a fax cover page based on sender and recipient info."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        var senderName: String
        var recipientName: String
        var subject: String
        var notes: String?
    }

    @Generable
    struct Result: PromptRepresentable {
        var coverPageText: String
    }

    func call(arguments: Arguments) async throws -> Result {
        let text = """
        FAX COVER PAGE
        -----------------
        From: \(arguments.senderName)
        To: \(arguments.recipientName)
        Subject: \(arguments.subject)
        Notes: \(arguments.notes ?? "")
        """
        return Result(coverPageText: text)
    }
}
