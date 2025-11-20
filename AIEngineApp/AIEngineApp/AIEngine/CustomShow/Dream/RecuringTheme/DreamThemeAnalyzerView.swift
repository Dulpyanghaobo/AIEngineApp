//
//  DreamThemeAnalyzerView.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import SwiftUI

struct DreamThemeAnalyzerView: View {
    
    // 定义Picker的选项
    enum AnalysisPeriod: String, CaseIterable, Identifiable {
        case lastMonth = "last_month"
        case lastThreeYears = "last_three_years"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .lastMonth:
                return "最近一个月"
            case .lastThreeYears:
                return "最近三年"
            }
        }
    }
    
    @StateObject private var aiEngine: AIEngine
    @State private var selectedPeriod: AnalysisPeriod = .lastThreeYears
    @State private var analysisResult: String = ""
    @State private var isLoading: Bool = false

    init() {
        // 1. 创建新工具的实例
        let themeTool = AnalyzeRecurringThemesTool()
        
        // 2. 配置 AIEngine，注入新工具并提供详细指令
        let config = AIEngineConfiguration(
            tools: [themeTool], // 只注入这个视图需要的工具
            defaultInstructions: """
            You are a dream analysis assistant. Your goal is to help the user understand recurring themes in their dreams.
            - You have a tool named 'analyzeRecurringThemes' which takes a 'period' ('last_month' or 'last_three_years').
            - When the user wants to analyze their dreams, you MUST call this tool with the specified period.
            - After the tool returns a list of themes and their counts, you must present this information to the user in a clear, insightful, and helpful summary.
            - Start by stating the most frequent themes, then you can offer some general psychological interpretations of those themes.
            - Always end by asking an open-ended question to encourage further reflection. For example: '您想深入探讨其中的哪个主题吗？'
            """
        )
        _aiEngine = StateObject(wrappedValue: AIEngine(configuration: config))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Picker("选择分析周期", selection: $selectedPeriod) {
                    ForEach(AnalysisPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                
                Button(action: analyzeThemes) {
                    Label("分析重复主题", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView("分析中，请稍候...")
                }
                
                if !analysisResult.isEmpty {
                    VStack(alignment: .leading) {
                        Text("分析结果")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        ScrollView {
                            Text(analysisResult)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("梦境主题分析")
            .onAppear(perform: aiEngine.checkAvailability)
        }
    }
    
    private func analyzeThemes() {
        isLoading = true
        analysisResult = ""
        
        // 构造一个清晰的Prompt，告诉模型要分析哪个时间段
        let prompt = "请帮我分析一下我 \(selectedPeriod.displayName) 的梦境里，有哪些重复出现的主题。"
        
        Task {
            // 这里我们使用单次请求，而不是一个持续的ChatSession
            let session = aiEngine.startChatSession()
            let stream = session.sendMessage(prompt)
            
            var fullResponse = ""
            for try await partialResponse in stream {
                fullResponse = partialResponse
                analysisResult = fullResponse // 直接更新，实现流式输出
            }
            isLoading = false
        }
    }
}