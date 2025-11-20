import SwiftUI

struct SummarizerView: View {
    @StateObject private var aiEngine = AIEngine()
    
    // 1. Declare a @FocusState variable to track the keyboard's focus.
    @FocusState private var isTextEditorFocused: Bool
    
    @State private var inputText = "Apple Intelligence is a personal intelligence system for iPhone, iPad, and Mac that combines the power of generative models with personal context to deliver intelligence that’s incredibly useful and relevant. It is deeply integrated into iOS 18, iPadOS 18, and macOS Sequoia. Apple’s unique approach combines on-device processing with server-based models to deliver a private and secure experience."
    @State private var summary: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Enter text below to get a summary.")
                    .font(.headline)
                
                TextEditor(text: $inputText)
                    .frame(height: 200)
                    .border(Color.gray.opacity(0.2), width: 1)
                    .cornerRadius(8)
                    // 2. Bind the TextEditor's focus to our state variable.
                    .focused($isTextEditorFocused)

                Button(action: generateSummary) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("Generate Summary", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || inputText.isEmpty)

                if !summary.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Summary").font(.headline)
                        ScrollView {
                            Text(summary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if let errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Text Summarizer")
            // 3. Add a toolbar with a "Done" button that appears with the keyboard.
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

    private func generateSummary() {
        // Also dismiss the keyboard when the generate button is tapped.
        isTextEditorFocused = false
        
        isLoading = true
        summary = ""
        errorMessage = nil
        
        let prompt = "Summarize the following text in a single, concise paragraph: \(inputText)"
        
        Task {
            do {
                let stream = aiEngine.generateResponse(for: prompt)
                for try await token in stream {
                    summary += token
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
