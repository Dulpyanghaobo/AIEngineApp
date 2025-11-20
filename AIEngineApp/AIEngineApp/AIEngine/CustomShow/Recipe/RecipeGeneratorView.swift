//
//  RecipeGeneratorView.swift
//  AIEngineApp
//
//  Created by i564407 on 9/28/25.
//


import SwiftUI

struct RecipeGeneratorView: View {
    @StateObject private var aiEngine = AIEngine()

    @State private var ingredientsText = "chicken breast, tomatoes, basil, garlic"
    @State private var recipe: Recipe.PartiallyGenerated?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter ingredients...", text: $ingredientsText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextEditorFocused)
                    Button("Generate", action: generateRecipe)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .disabled(isLoading)

                if isLoading && recipe == nil {
                    ProgressView("Generating your delicious recipe...")
                }
                
                if let recipe {
                    RecipeView(recipe: recipe)
                }
                
                if let errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .navigationTitle("Recipe Bot")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer() // Pushes the button to the right
                    Button("Done") {
                        isTextEditorFocused = false // This dismisses the keyboard
                    }
                }
            }
            .onAppear(perform: aiEngine.checkAvailability)
        }
    }

    private func generateRecipe() {
        isLoading = true
        recipe = nil
        errorMessage = nil
        
        let prompt = "Generate a simple recipe using the following ingredients: \(ingredientsText). Be creative."
        
        Task {
            do {
                let stream = aiEngine.generate(structuredResponseFor: prompt, ofType: Recipe.self)
                for try await partialRecipe in stream {
                    self.recipe = partialRecipe
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// 用于显示食谱的子视图
struct RecipeView: View {
    let recipe: Recipe.PartiallyGenerated

    var body: some View {
        List {
            if let title = recipe.title, !title.isEmpty {
                Section {
                    Text(title).font(.largeTitle.bold())
                    if let summary = recipe.summary { Text(summary).foregroundStyle(.secondary) }
                }
            }
            
            if let ingredients = recipe.ingredients {
                Section("Ingredients") {
                    ForEach(ingredients, id: \.self) { ingredient in
                        HStack {
                            Text(ingredient.name ?? "...")
                            Spacer()
                            Text(ingredient.quantity ?? "")
                        }
                    }
                }
            }

            if let instructions = recipe.instructions {
                Section("Instructions") {
                    ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)")
                    }
                }
            }
        }
        .animation(.default, value: recipe)
    }
}
