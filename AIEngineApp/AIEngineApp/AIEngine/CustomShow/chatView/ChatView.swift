import SwiftUI

struct SmartAssistantView: View {
    // 为这个视图创建一个专门配置了工具的AIEngine
    private static let dreamInterpreterConfig = AIEngineConfiguration(
        tools: [DreamSymbolTool()],
        defaultInstructions: """
        你是一位温柔、富有洞察力且充满同理心的解梦师。你的目标是通过一场支持性的、由问题驱动的对话，帮助用户探索和理解他们自己的梦境。

        你的工作流程如下：
        1.  仔细聆听用户对梦境的描述。
        2.  根据用户的回答，识别出梦中的关键情绪、人物、物品和事件。然后，每次只提出一个开放式的、引人反思的后续问题，以鼓励用户进行更深入的探索。例如，可以问“这让你有什么感觉？”或“接下来发生了什么？”。
        3.  避免给出绝对的、结论性的解释。你的任务是引导用户自己找到答案，而不是直接告诉他们答案。

        工具使用规则 (非常重要):
        你拥有一个强大的工具: `getDreamSymbolMeaning`。
        - 当用户提到一个常见的梦境符号时（例如：飞翔、坠落、蛇、水、牙齿等），你必须使用这个工具来查询其通用的心理学含义。
        - 从工具获取到含义后，你绝不能直接陈述这个定义。你必须将工具返回的信息巧妙地融入到你的下一个问题中，以帮助用户将符号的通用含义与他们自己的生活联系起来。
        - 示例：如果工具返回“坠落象征着失控感”，你应该这样提问：“你梦到了坠落，这很有趣。坠落的感觉有时与现实生活中对某件事失去控制的感觉有关。你最近有类似的感觉吗？”

        对话目标:
        经过几轮交流后（通常是4-6个问题），当你感觉用户已经探讨了梦境的核心要素时，主动提出为他们做一个简短的总结，概述你们的对话和可能发现的见解。最后以支持和鼓励的语气结束对话。
        """
    )
    
    // 我们重用之前设计的ChatView，但传入一个配置了Tool的AIEngine
    // 这展示了我们模块设计的强大之处
    @StateObject private var aiEngine = AIEngine(configuration: dreamInterpreterConfig)
    @StateObject private var chatSession: ChatSession

    init() {
        let engine = AIEngine(configuration: Self.dreamInterpreterConfig)
        _aiEngine = StateObject(wrappedValue: engine)
        _chatSession = StateObject(wrappedValue: engine.startChatSession(with: [
                    .init(role: .assistant, content: "你好，我是你的解梦师。准备好后，请随时开始描述你的梦境，我会在这里倾-听和引导。")
                ]))
    }
    
    var body: some View {
        // 为了演示，我们直接复用ChatView的UI和逻辑
        // 在真实项目中，你可以为此创建一个新的专用视图
        ChatView(aiEngine: aiEngine, chatSession: chatSession)
            .navigationTitle("Smart Assistant")
    }
}

// 需要稍微修改ChatView以接受外部的AIEngine和ChatSession
// 这样可以使其更加灵活和可重用
struct ChatView: View {
    @StateObject private var aiEngine: AIEngine
    @StateObject private var chatSession: ChatSession
    
    @State private var userInput: String = ""
    @FocusState private var isTextEditorFocused: Bool

    // 修改init使其可以接收外部对象
    init(aiEngine: AIEngine, chatSession: ChatSession) {
        _aiEngine = StateObject(wrappedValue: aiEngine)
        _chatSession = StateObject(wrappedValue: chatSession)
    }
    
    // ... ChatView的其余代码保持不变 ...
    var body: some View {
         VStack {
             switch aiEngine.state {
             case .checkingAvailability:
                 ProgressView("Checking AI availability...")
             case .available:
                 // AI可用，显示聊天界面
                 chatInterface
             case .unavailable(let reason):
                 ContentUnavailableView(
                     "AI Not Available",
                     systemImage: "exclamationmark.triangle",
                     description: Text(reason)
                 )
             }
         }
         .toolbar {
             ToolbarItemGroup(placement: .keyboard) {
                 Spacer() 
                 Button("Done") {
                     isTextEditorFocused = false
                 }
             }
         }
         .onAppear {
             // 2. 检查模型可用性
             aiEngine.checkAvailability()
         }
     }

     private var chatInterface: some View {
         VStack {
             ScrollViewReader { proxy in
                 ScrollView {
                     ForEach(chatSession.history) { message in
                         ChatMessageView(message: message)
                             .id(message.id)
                     }
                 }
                 .onChange(of: chatSession.history) {
                     proxy.scrollTo(chatSession.history.last?.id, anchor: .bottom)
                 }
             }

             HStack {
                 TextField("Ask something...", text: $userInput, axis: .vertical)
                     .textFieldStyle(.roundedBorder)
                     .lineLimit(5)
                     .disabled(chatSession.isResponding)
                     .focused($isTextEditorFocused)
                 
                 if chatSession.isResponding {
                     ProgressView().padding(.horizontal)
                 } else {
                     Button(action: sendMessage) {
                         Image(systemName: "arrow.up.circle.fill")
                             .font(.title)
                     }
                     .disabled(userInput.isEmpty)
                 }
             }
         }
         .padding()
     }

    private func sendMessage() {
        let prompt = userInput
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        userInput = ""

        Task {
            // 1. 为 AI 的回复创建一个空的“占位”消息，并获取其唯一ID
            let assistantMessageId = UUID()
            chatSession.addMessage(.init(id: assistantMessageId, role: .assistant, content: ""))

            do {
                // 2. 调用 session 的 sendMessage。
                //    它会处理用户消息的添加，并返回一个流。
                let stream = chatSession.sendMessage(prompt)
                
                // 3. 遍历流。每次循环，`partialResponse` 都是“到目前为止的完整回复”
                for try await partialResponse in stream {
                    // 4. 【关键修正】用最新的`partialResponse`**替换**占位消息的全部内容
                    chatSession.updateMessageContent(id: assistantMessageId, newContent: partialResponse)
                }
            } catch {
                // 如果出错，更新占位消息为错误提示
                chatSession.updateMessageContent(id: assistantMessageId, newContent: "抱歉，出错了: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - ChatView的辅助组件 (为了代码清晰)
struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 50) }
            
            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            if message.role == .assistant { Spacer(minLength: 50) }
        }
    }
}
