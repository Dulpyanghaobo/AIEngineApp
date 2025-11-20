//
//  ContentTaggerView.swift
//  AIEngineApp
//
//  Created by i564407 on 9/28/25.
//


import SwiftUI

struct ContentTaggerView: View {
    // 使用为内容标签优化的配置
    @StateObject private var aiEngine = AIEngine(configuration: .contentTagger)

    @State private var inputText = "I felt so happy and excited when I bought a new camera for our family trip to the beach."
    @State private var tagResult: ContentTaggingResult.PartiallyGenerated?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextEditor(text: $inputText)
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.2), width: 1)
                    .cornerRadius(8)
                    .focused($isTextEditorFocused)

                Button(action: generateTags) {
                    Label("Generate Tags", systemImage: "tag.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || inputText.isEmpty)

                if isLoading {
                    ProgressView()
                }

                if let result = tagResult {
                    TagResultView(result: result)
                }
                
                if let errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Content Tagger")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer() // Pushes the button to the right
                    Button("Done") {
                        isTextEditorFocused = false // This dismisses the keyboard
                    }
                }
            }
            .onAppear {
                aiEngine.checkAvailability()
            }
        }
    }

    private func generateTags() {
        isLoading = true
        tagResult = nil
        errorMessage = nil
        
        Task {
            do {
                let stream = aiEngine.generate(structuredResponseFor: inputText, ofType: ContentTaggingResult.self)
                for try await partialResult in stream {
                    self.tagResult = partialResult
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// 用于显示标签结果的子视图
struct TagResultView: View {
    let result: ContentTaggingResult.PartiallyGenerated

    var body: some View {
        List {
            TagSectionView(title: "Topics", tags: result.topics)
            TagSectionView(title: "Actions", tags: result.actions)
            TagSectionView(title: "Emotions", tags: result.emotions)
            TagSectionView(title: "Objects", tags: result.objects)
        }
    }
}

struct TagSectionView: View {
    let title: String
    let tags: [String]?

    var body: some View {
        if let tags, !tags.isEmpty {
            Section(header: Text(title)) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                }
            }
        }
    }
}
