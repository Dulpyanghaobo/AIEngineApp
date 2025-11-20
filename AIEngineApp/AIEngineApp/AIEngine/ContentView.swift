import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OnDeviceVsCloudList()
                .tabItem {
                    Label("On-Device vs Cloud", systemImage: "bolt.horizontal.circle")
                }

            OnDeviceUseCasesList()
                .tabItem {
                    Label("On-Device Use Cases", systemImage: "wand.and.stars")
                }
        }
    }
}

private struct OnDeviceVsCloudList: View {
    var body: some View {
        NavigationStack {
            List {
                Section("AI Assist Write") {
                    NavigationLink("Foundation Model Demo", destination: FoundationModelDemoView())
                    
                    NavigationLink("Safety Demo", destination: SafetyDemoView())
                    NavigationLink("Prompt Demo", destination: PromptBuilderPracticeView())

                    NavigationLink("AI Assist Write", destination: AIAssistWriteView())
                    
                    NavigationLink("Multilingual Demo", destination: MultilingualDemoView())
                    
                    NavigationLink("ToolFaxScan Demo", destination: ToolFaxScanDemoView())
                    
                    NavigationLink("WorkflowToolTranscript Demo", destination: WorkflowToolTranscriptDemoView())
                }
                
                Section("Generable") {
                    NavigationLink("GenerableWorkflow Demo", destination: GenerableWorkflowDemoView())
                    NavigationLink("DynamicGenerationSchemaDemoView Demo", destination: DynamicGenerationSchemaDemoView())
                    NavigationLink("GenerableVsDynamicDemoView Demo", destination: GenerableVsDynamicDemoView())
                    NavigationLink("DynamicFaxPlanSelection Demo", destination: DynamicFaxPlanSelectionDemoView())
                    NavigationLink("DynamicOCRLanguageSelection Demo", destination: DynamicOCRLanguageSelectionDemoView())
                    NavigationLink("DynamicPDFCompression Demo", destination: DynamicPDFCompressionDemoView())
                    NavigationLink("DynamicContactSelection Demo", destination: DynamicContactSelectionDemoView())
                    NavigationLink("DynamicScanPreset Demo", destination: DynamicScanPresetDemoView())
                    NavigationLink("DynamicWorkflowSchema Demo", destination: DynamicWorkflowSchemaDemoView())
                }

                Section("Transcript") {
                    NavigationLink("FaxDiagnostic View", destination: JetFaxDiagnosticView())
                    NavigationLink("AIHubDemo View", destination: AIHubDemoView())
                }
                
                Section("AI Attchment") {
                    NavigationLink("Attchment Entity Extractor", destination: AttachmentEntityExtractorView())
                    NavigationLink("Attchment Generate Extractor", destination: AttachmentAIGenerateView())
                }
            }
            .navigationTitle("On-Device vs Cloud LLMs")
        }
    }
}

private struct OnDeviceUseCasesList: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Recipe Generator", destination: RecipeGeneratorView())
                NavigationLink("Smart Assistant", destination: SmartAssistantView())
                NavigationLink("Dream Context Analyzer", destination: DreamContextAnalyzerView())
                NavigationLink("Dream Theme Analyzer", destination: DreamThemeAnalyzerView())
                NavigationLink("Dream Search", destination: DreamSearchView())
                NavigationLink("Summarizer", destination: SummarizerView())
                NavigationLink("AI Watermark", destination: AIWatermarkView())
            }
            .navigationTitle("On-Device Use Cases")
        }
    }
}
