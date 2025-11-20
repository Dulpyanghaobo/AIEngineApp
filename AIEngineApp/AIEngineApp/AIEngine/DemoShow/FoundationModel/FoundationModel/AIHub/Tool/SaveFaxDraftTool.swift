//
//  SaveFaxDraftTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


// SaveFaxDraftTool.swift

import Foundation
import FoundationModels

struct SaveFaxDraftTool: Tool {
    let name = "saveFaxDraft"
    let description = "将当前文档保存为草稿传真，稍后可以继续编辑或发送"

    let database: FaxDatabaseService

    @Generable
    struct Args {
        /// 当前文档 ID（例如扫描结果或 PDF）
        var documentId: String
        /// 可选：预填的传真号码
        var toFaxNumber: String?
    }

    @Generable
    struct Output {
        var draftFaxId: String
        var documentId: String
        var toFaxNumber: String?
        var createdAt: String
    }

    func call(arguments: Args) async throws -> Output {
        let draft = await database.createDraft(
            documentId: arguments.documentId,
            to: arguments.toFaxNumber
        )

        let formatter = ISO8601DateFormatter()

        return Output(
            draftFaxId: draft.id,
            documentId: draft.documentId,
            toFaxNumber: draft.to,
            createdAt: formatter.string(from: draft.createdAt)
        )
    }
}
