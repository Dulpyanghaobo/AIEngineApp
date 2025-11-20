//
//  CropRect.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


// FaxEditService.swift

import Foundation

struct CropRect: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct CropResult: Codable {
    var newDocumentId: String
    var pageIndex: Int
    var appliedRect: CropRect
}

struct FaxEditService {

    func crop(documentId: String, pageIndex: Int, rect: CropRect) async -> CropResult {
        let newId = "\(documentId)_CROPPED_PAGE_\(pageIndex)"

        print("""
        ✂️ [FaxEditService] Crop document:
        - originalId: \(documentId)
        - pageIndex: \(pageIndex)
        - rect: (\(rect.x), \(rect.y), \(rect.width), \(rect.height))
        - newId: \(newId)
        """)

        return CropResult(
            newDocumentId: newId,
            pageIndex: pageIndex,
            appliedRect: rect
        )
    }
}
