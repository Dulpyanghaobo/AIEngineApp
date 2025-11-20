import SwiftUI

struct DreamContextAnalyzerView: View {
    @StateObject private var aiEngine: AIEngine
    
    // 模拟用户是否已授予权限
    @State private var healthPermissionGranted = true
    @State private var calendarPermissionGranted = true
    
    @State private var analysisResult: String = ""
    @State private var isLoading: Bool = false
    
    // 将模拟管理器作为State，以便在视图中使用
    @State private var healthManager: HealthKitManager
    @State private var calendarManager: CalendarManager
// 苹果的铭感次有点多，所以需要做一些处理
    init() {
        // 1. 先在 init 内部创建管理器的本地实例
        let localHealthManager = HealthKitManager()
        let localCalendarManager = CalendarManager()
        
        // 2. 使用本地实例来创建工具
        let contextTool = CorrelateWithRealWorldDataTool(
            healthManager: localHealthManager,
            calendarManager: localCalendarManager
        )
        
        // 3. 使用工具来配置 AIEngine
        let config = AIEngineConfiguration(
            tools: [contextTool],
            defaultInstructions: """
            You are an insightful and empathetic wellness assistant.
            - Your goal is to help the user understand the connection between their real life and their dreams.
            - You have a powerful tool: 'correlateWithRealWorldData'.
            - When a user asks why their dreams were a certain way (e.g., anxious, strange), you MUST call this tool to get context.
            - The tool will return an object with sleep data, calendar events, and a summary.
            - You MUST use the 'summary' from the tool's output as the basis for your answer.
            - Your response should be gentle and validating. Start by acknowledging the user's feelings, then present the data-driven insights from the tool's summary.
            - Example response: "您感到焦虑是可以理解的。通过分析您（已授权）的数据，我发现您上周的睡眠质量似乎不太好，平均睡眠时长较短，并且日历上有一个重要的项目截止日期。这些现实生活中的压力，很可能是导致您梦境焦虑的原因。"
            - If the tool's summary indicates a lack of data, gently inform the user.
            """
        )
        
        // 4. 现在，使用准备好的所有“零件”来初始化视图的属性
        self._aiEngine = StateObject(wrappedValue: AIEngine(configuration: config))
        self._healthManager = State(wrappedValue: localHealthManager)
        self._calendarManager = State(wrappedValue: localCalendarManager)
    }
    // ▲▲▲ 修改结束 ▲▲▲
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                VStack(alignment: .leading) {
                    Text("模拟授权")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("允许访问健康数据 (睡眠)", isOn: $healthPermissionGranted)
                    Toggle("允许访问日历数据", isOn: $calendarPermissionGranted)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Button(action: analyzeContext) {
                    Label("分析我上周的焦虑梦境", systemImage: "arrow.left.arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView("正在关联分析，请稍候...")
                }
                
                if !analysisResult.isEmpty {
                    VStack(alignment: .leading) {
                        Text("洞察分析")
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
            .navigationTitle("梦境与现实关联")
            .onAppear(perform: aiEngine.checkAvailability)
        }
    }
    
    private func analyzeContext() {
        isLoading = true
        analysisResult = ""

        Task {
            do {
                // 先请求系统权限
                let healthOK = try await healthManager.requestAuthorization()
                let calendarOK = try await calendarManager.requestAuthorization()

                if !healthOK && !calendarOK {
                    analysisResult = "⚠️ 无法访问健康或日历数据，请到设置中开启权限。"
                    isLoading = false
                    return
                }

                // 使用 AIEngine 调用 Tool
                let prompt = "为什么我上周的梦都那么焦虑？"
                let session = aiEngine.startChatSession()
                let stream = session.sendMessage(prompt)

                for try await partial in stream {
                    analysisResult = partial
                }

            } catch {
                analysisResult = "❌ 授权失败：\(error.localizedDescription)"
            }

            isLoading = false
        }
    }

}
