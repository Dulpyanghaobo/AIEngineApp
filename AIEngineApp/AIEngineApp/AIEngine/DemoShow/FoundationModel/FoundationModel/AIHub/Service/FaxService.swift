//
//  FaxService.swift
//  AIEngineApp
//

import Foundation

struct FaxSendResult: Codable {
    var faxId: String
    var status: String
    var price: Double
}

struct FaxService {

    func send(documentId: String, faxNumber: String) async throws -> FaxSendResult {

        print("""
        📨 [FaxService] Sending fax...
        - documentId: \(documentId)
        - faxNumber: \(faxNumber)
        """)

        try await Task.sleep(nanoseconds: 1_000_000_000) // 模拟延迟 1 秒

        let faxId = "FAX-\(Int.random(in: 1000...9999))"
        let price = Double.random(in: 0.05...0.25)

        print("""
        ✅ [FaxService] Fax queued
        - faxId: \(faxId)
        - estimatedPrice: \(price)
        """)

        return FaxSendResult(
            faxId: faxId,
            status: "queued",
            price: price
        )
    }
}
