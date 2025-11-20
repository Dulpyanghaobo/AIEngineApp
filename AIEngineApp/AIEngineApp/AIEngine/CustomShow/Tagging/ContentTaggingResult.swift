//
//  ContentTaggingResult.swift
//  AIEngineApp
//
//  Created by i564407 on 9/28/25.
//


import Foundation
import FoundationModels

@Generable
struct ContentTaggingResult: Equatable {
    @Guide(
        description: "The most important actions in the text.",
        .maximumCount(3)
    )
    var actions: [String]

    @Guide(
        description: "The most prominent emotions conveyed in the text.",
        .maximumCount(3)
    )
    var emotions: [String]

    @Guide(
        description: "The key objects or items mentioned.",
        .maximumCount(5)
    )
    var objects: [String]
    
    @Guide(
        description: "The main topics of the text.",
        .maximumCount(3)
    )
    var topics: [String]
}
