//
//  Recipe.swift
//  AIEngineApp
//
//  Created by i564407 on 9/28/25.
//


import Foundation
import FoundationModels

@Generable
struct Recipe: Equatable {
    @Guide(description: "A creative and appealing name for the recipe.")
    var title: String
    
    @Guide(description: "A brief, one-sentence summary of the dish.")
    var summary: String
    
    var ingredients: [Ingredient]
    var instructions: [String]
}

@Generable
struct Ingredient: Equatable, Hashable {
    var name: String
    var quantity: String
}