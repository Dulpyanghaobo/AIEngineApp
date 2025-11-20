//
//  AddCoverPageTool.swift
//

import Foundation
import FoundationModels

struct AddCoverPageTool: Tool {
    let name = "addCoverPage"
    let description = "根据场景生成对应的封面页并返回新文档ID"

    let cover: CoverPageService

    @Generable
    struct Args {
        var documentId: String
        var scenario: String
    }

    @Generable
    struct Output {
        var newDocumentId: String
        var coverId: String
        var generatedAt: String
    }

    func call(arguments: Args) async throws -> Output {
        let c = await cover.generate(for: arguments.scenario)

        print("""
        🟦 [AddCoverPageTool]
        Generated cover:
        - id: \(c.id)
        - scenario: \(c.scenario)
        """)

        return Output(
            newDocumentId: "\(arguments.documentId)_WITH_\(c.id)",
            coverId: c.id,
            generatedAt: ISO8601DateFormatter().string(from: c.generatedAt)
        )
    }
}
