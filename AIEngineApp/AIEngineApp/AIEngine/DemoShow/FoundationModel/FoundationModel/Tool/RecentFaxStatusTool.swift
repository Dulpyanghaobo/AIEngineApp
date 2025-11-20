//
//  RecentFaxStatusTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//
import FoundationModels

struct RecentFaxStatusTool: Tool {
    let name = "queryRecentFaxStatus"
    let description = "Returns the status of recent fax logs."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        @Guide(description: "Limit number of results", .range(1...20))
        var limit: Int
    }

    @Generable
    struct FaxItem: PromptRepresentable {
        var id: String
        var pages: Int
        var status: String
        var timestamp: String
    }

    @Generable
    struct Result: PromptRepresentable {
        var items: [FaxItem]
    }

    func call(arguments: Arguments) async throws -> Result {
        let logs = [
            FaxItem(id: "fax001", pages: 3, status: "Delivered", timestamp: "2025-11-19 10:22"),
            FaxItem(id: "fax002", pages: 12, status: "Pending", timestamp: "2025-11-19 10:50"),
            FaxItem(id: "fax003", pages: 5, status: "Failed", timestamp: "2025-11-19 11:10")
        ]

        return Result(items: Array(logs.prefix(arguments.limit)))
    }
}
