import SwiftUI

struct AIAssistWriteView: View {
    @State private var inputText: String =
        "Please review the attached report and share clear, actionable feedback."
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Start typing below and use the Writing Assistant above the keyboard.")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                AIWritingAssistantTextEditor(text: $inputText)
                    .frame(minHeight: 200, maxHeight: .infinity)
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI Assist Write")
        }
    }
}
