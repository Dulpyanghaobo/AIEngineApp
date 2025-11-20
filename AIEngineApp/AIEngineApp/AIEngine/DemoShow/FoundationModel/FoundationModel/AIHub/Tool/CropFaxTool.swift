//
//  CropFaxTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


// CropFaxTool.swift

import Foundation
import FoundationModels

struct CropFaxTool: Tool {
    let name = "cropFax"
    let description = "对当前文档的指定页面进行裁剪，返回新的文档ID"

    let edit: FaxEditService

    @Generable
    struct Args {
        var documentId: String
        var pageIndex: Int

        /// 裁剪区域（归一化坐标 0~1，或由你在 Instructions 里解释清楚）
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    @Generable
    struct Output {
        var newDocumentId: String
        var pageIndex: Int
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    func call(arguments: Args) async throws -> Output {
        let rect = CropRect(
            x: arguments.x,
            y: arguments.y,
            width: arguments.width,
            height: arguments.height
        )

        let result = await edit.crop(
            documentId: arguments.documentId,
            pageIndex: arguments.pageIndex,
            rect: rect
        )

        return Output(
            newDocumentId: result.newDocumentId,
            pageIndex: result.pageIndex,
            x: result.appliedRect.x,
            y: result.appliedRect.y,
            width: result.appliedRect.width,
            height: result.appliedRect.height
        )
    }
}
