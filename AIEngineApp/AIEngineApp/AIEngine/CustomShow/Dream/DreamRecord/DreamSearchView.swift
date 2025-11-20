import SwiftUI

struct DreamSearchView: View {
    
    // 持有配置了新工具的 AIEngine 实例
    @StateObject private var aiEngine: AIEngine
    
    // 管理当前聊天会话的状态
    @StateObject private var chatSession: ChatSession
    
    @State private var inputText: String = ""
    
    init() {
        // 1. 创建我们的新工具实例
        let dreamTool = FetchDreamHistoryTool()
        
        // 2. 创建一个包含该工具和特定指令的 AIEngine 配置
        let config = AIEngineConfiguration(
            tools: [dreamTool], // <--- 在这里注入我们的工具
            defaultInstructions: """
            You are a dream assistant. You have access to a tool called 'fetchDreamHistory'
            that can search the user's dream diary.
            - The tool takes a 'keyword' and a 'period'.
            - The only supported value for 'period' is 'last_month'.
            - When the user asks to find dreams, use this tool.
            - After getting the search results from the tool, present them to the user in a natural and helpful way.
            """
        )
        
        // 3. 使用此配置初始化 AIEngine 和 ChatSession
        let engine = AIEngine(configuration: config)
        _aiEngine = StateObject(wrappedValue: engine)
        _chatSession = StateObject(wrappedValue: engine.startChatSession())
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 修改 1: 使用 ScrollViewReader 以实现自动滚动
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(chatSession.history) { message in
                                ChatBubble(message: message)
                                    .id(message.id) // 为每条消息设置ID
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatSession.history) {
                        // 当 history 变化时，滚动到最新的消息
                        proxy.scrollTo(chatSession.history.last?.id, anchor: .bottom)
                    }
                }
                
                // 底部输入区域 (保持不变)
                HStack {
                    TextField("例如: '帮我找找关于飞行的梦'", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(chatSession.isResponding)

                    if chatSession.isResponding {
                        ProgressView()
                    } else {
                        Button("发送", action: sendMessage)
                            .disabled(inputText.isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("梦境检索助手")
            .onAppear(perform: aiEngine.checkAvailability)
        }
    }
    
    // 修改 2: 重写 sendMessage 函数，使其与 ChatView 的逻辑完全一致
    private func sendMessage() {
        let prompt = inputText
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        inputText = ""
        
        // 将用户消息添加到 history
        chatSession.addMessage(.init(role: .user, content: prompt))

        Task {
            // 1. 为 AI 的回复创建一个空的“占位”消息，并获取其唯一ID
            let assistantMessageId = UUID()
            chatSession.addMessage(.init(id: assistantMessageId, role: .assistant, content: "思考中..."))

            do {
                // 2. 调用 session 的 sendMessage 来获取数据流
                let stream = chatSession.sendMessage(prompt)
                
                var firstChunkReceived = false
                
                // 3. 遍历流，用收到的内容更新占位消息
                for try await partialResponse in stream {
                    // 优化：第一次收到内容时，清空"思考中..."的提示
                    if !firstChunkReceived {
                        chatSession.updateMessageContent(id: assistantMessageId, newContent: "")
                        firstChunkReceived = true
                    }
                    chatSession.updateMessageContent(id: assistantMessageId, newContent: partialResponse)
                }
            } catch {
                // 如果出错，更新占位消息为错误提示
                chatSession.updateMessageContent(id: assistantMessageId, newContent: "抱歉，出错了: \(error.localizedDescription)")
            }
        }
    }
}

// 用于显示聊天气泡的辅助视图 (可以复用)
fileprivate struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(16)
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}
