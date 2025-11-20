//
//  CoverPageService.swift
//  AIEngineApp
//

import Foundation

struct CoverPage: Codable {
    var id: String
    var scenario: String
    var generatedAt: Date
}

struct CoverPageService {

    func generate(for scenario: String) async -> CoverPage {
        let cover = CoverPage(
            id: "COVER-\(scenario.uppercased())-\(Int.random(in: 1000...9999))",
            scenario: scenario,
            generatedAt: Date()
        )

        print("""
        🟦 [CoverPageService]
        Generated cover page:
        - id: \(cover.id)
        - scenario: \(cover.scenario)
        - date: \(cover.generatedAt)
        """)

        return cover
    }
}
