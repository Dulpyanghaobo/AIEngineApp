//
//  FaxRecord.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


// FaxDatabaseService.swift

import Foundation

struct FaxRecord: Codable, Identifiable {
    var id: String          // faxId 或 draftId
    var to: String
    var status: String      // "queued" / "sent" / "failed" / "draft"
    var createdAt: Date
    var documentId: String
}

actor FaxDatabaseService {

    private var records: [FaxRecord] = [
        // Demo 内置几条方便测试
        FaxRecord(
            id: "FAX-1001",
            to: "+1 202-111-2222",
            status: "sent",
            createdAt: Date().addingTimeInterval(-3600 * 24),
            documentId: "DOC-IRS-2024"
        ),
        FaxRecord(
            id: "FAX-1002",
            to: "+1 415-333-4444",
            status: "queued",
            createdAt: Date().addingTimeInterval(-3600),
            documentId: "DOC-CONTRACT-01"
        )
    ]

    func search(keyword: String, status: String?) async -> [FaxRecord] {
        let kw = keyword.lowercased()

        return records.filter { r in
            let matchKeyword = kw.isEmpty
            || r.id.lowercased().contains(kw)
            || r.to.lowercased().contains(kw)
            || r.documentId.lowercased().contains(kw)

            let matchStatus: Bool
            if let s = status, !s.isEmpty {
                matchStatus = r.status.lowercased() == s.lowercased()
            } else {
                matchStatus = true
            }

            return matchKeyword && matchStatus
        }
    }

    func createDraft(documentId: String, to: String?) async -> FaxRecord {
        let draft = FaxRecord(
            id: "DRAFT-\(Int.random(in: 1000...9999))",
            to: to ?? "",
            status: "draft",
            createdAt: Date(),
            documentId: documentId
        )
        records.append(draft)

        print("""
        📝 [FaxDatabaseService] Created draft:
        - id: \(draft.id)
        - to: \(draft.to)
        - documentId: \(draft.documentId)
        """)

        return draft
    }

    func addSentFax(from result: FaxSendResult, to: String, documentId: String) async {
        let record = FaxRecord(
            id: result.faxId,
            to: to,
            status: result.status,
            createdAt: Date(),
            documentId: documentId
        )
        records.append(record)

        print("""
        🗂 [FaxDatabaseService] Added sent fax:
        - id: \(record.id)
        - to: \(record.to)
        - documentId: \(record.documentId)
        """)
    }
}
