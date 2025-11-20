//
//  WAAnalyzeSheet.swift
//  AIEngineApp
//
//  Created by i564407 on 11/17/25.
//


import SwiftUI

struct WAAnalyzeSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var phase: WAAnalyzePhase = .loading
    @State private var suggestions: [WAAnalyzeSuggestion] = []
    @State private var workingText: String
    
    let originalText: String
    let analyzeAction: (String) async throws -> [WAAnalyzeSuggestion]
    let onFinish: (String) -> Void
    
    init(
        originalText: String,
        analyzeAction: @escaping (String) async throws -> [WAAnalyzeSuggestion],
        onFinish: @escaping (String) -> Void
    ) {
        self.originalText = originalText
        self._workingText = State(initialValue: originalText)
        self.analyzeAction = analyzeAction
        self.onFinish = onFinish
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    loadingView
                case .suggestions:
                    suggestionsView
                case .done:
                    doneView
                }
            }
            .navigationTitle("Writing Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if phase == .suggestions {
                        Button("Done") {
                            phase = .done
                        }
                    }
                }
            }
        }
        .task {
            await runAnalyze()
        }
    }
}

// MARK: - 子视图
private extension WAAnalyzeSheet {
    var loadingView: some View {
        VStack {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
            Text("Analyzing...")
                .font(.title3)
                .padding(.top, 8)
            Spacer()
        }
    }
    
    var suggestionsView: some View {
        List {
            Section(header: Text("Suggestions (\(suggestions.count))")) {
                ForEach(suggestions.indices, id: \.self) { index in
                    suggestionRow(for: $suggestions[index])
                }
            }
        }
    }
    
    func suggestionRow(for suggestion: Binding<WAAnalyzeSuggestion>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Text("Sentence with issue:")
                    .font(.subheadline.bold())
                Text("\"\(suggestion.wrappedValue.originalSentence)\"")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
            
            Group {
                Text("Suggested text:")
                    .font(.subheadline.bold())
                Text("\"\(suggestion.wrappedValue.suggestedSentence)\"")
                    .font(.subheadline)
            }
            
            HStack {
                Button("Reject") {
                    suggestion.wrappedValue.handled = true
                    moveToDoneIfNeeded()
                }
                .frame(maxWidth: .infinity)
                
                Button("Accept") {
                    suggestion.wrappedValue.handled = true
                    applySuggestion(suggestion.wrappedValue)
                    moveToDoneIfNeeded()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 6)
        }
        .padding(.vertical, 6)
    }
    
    var doneView: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            Text("All done!")
                .font(.title3.bold())
                .padding(.top, 8)
            Spacer()
            Button("Close") {
                onFinish(workingText)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 行为
private extension WAAnalyzeSheet {
    func runAnalyze() async {
        do {
            let result = try await analyzeAction(originalText)
            await MainActor.run {
                self.suggestions = result
                self.phase = .suggestions
            }
        } catch {
            await MainActor.run {
                self.phase = .done
            }
        }
    }
    
    func applySuggestion(_ suggestion: WAAnalyzeSuggestion) {
        workingText = workingText.replacingOccurrences(
            of: suggestion.originalSentence,
            with: suggestion.suggestedSentence
        )
    }
    
    func moveToDoneIfNeeded() {
        if suggestions.allSatisfy(\.handled) {
            phase = .done
        }
    }
}
