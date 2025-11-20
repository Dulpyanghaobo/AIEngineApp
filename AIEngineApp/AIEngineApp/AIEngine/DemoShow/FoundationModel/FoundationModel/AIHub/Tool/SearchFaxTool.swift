//
//  SearchFaxTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


// SearchFaxTool.swift

import Foundation
import FoundationModels

struct SearchFaxTool: Tool {
    let name = "searchFax"
    let description = "根据收件人、传真号、文档ID或状态搜索历史传真记录"

    let database: FaxDatabaseService

    @Generable
    struct Args {
        /// 关键字，可匹配 faxId、收件人号码或 documentId
        var keyword: String
        /// 可选状态过滤：queued / sent / failed / draft
        var status: String?
    }

    @Generable
    struct Output {
        var results: [FaxItem]

        @Generable
        struct FaxItem {
            var faxId: String
            var to: String
            var status: String
            var createdAt: String
            var documentId: String
        }
    }

    func call(arguments: Args) async throws -> Output {
        let list = await database.search(keyword: arguments.keyword, status: arguments.status)

        let formatter = ISO8601DateFormatter()
        let mapped = list.map {
            Output.FaxItem(
                faxId: $0.id,
                to: $0.to,
                status: $0.status,
                createdAt: formatter.string(from: $0.createdAt),
                documentId: $0.documentId
            )
        }

        print("📡 [SearchFaxTool] 返回 \(mapped.count) 条传真记录")

        return Output(results: mapped)
    }
}
