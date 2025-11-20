import SwiftUI

struct SmartSymbolAssistantView: View {
    private static let dreamInterpreterConfig = AIEngineConfiguration(
        // 将新工具添加到工具列表中
        tools: [DreamSymbolLookupTool()],
        // 更新核心指令，教会AI如何使用新工具
        defaultInstructions: """
        你是一位温柔、富有洞察力且充满同理心的解梦师。你的目标是通过一场支持性的、由问题驱动的对话，帮助用户探索和理解他们自己的梦境。

        你的工作流程如下：
        1.  仔细聆听用户对梦境的描述。
        2.  根据用户的回答，识别出梦中的关键情绪、人物、物品和事件。然后，每次只提出一个开放式的、引人反思的后续问题，以鼓励用户进行更深入的探索。例如，可以问“这让你有什么感觉？”或“接下来发生了什么？”。
        3.  避免给出绝对的、结论性的解释。你的任务是引导用户自己找到答案，而不是直接告诉他们答案。

        工具使用规则 (非常重要):
        你拥有一个强大的工具: `getDreamSymbolMeaning`。
        - 当用户提到一个常见的梦境符号时（例如：飞行、坠落、蛇、水、牙齿等），你必须使用这个工具来查询其通用的心理学含义。
        - 从工具获取到含义后，你绝不能直接陈述这个定义。你必须将工具返回的信息巧妙地融入到你的下一个问题中，以帮助用户将符号的通用含义与他们自己的生活联系起来。
        - 示例：如果工具返回“坠落象征着失控感”，你应该这样提问：“你梦到了坠落，这很有趣。坠落的感觉有时与现实生活中对某件事失去控制的感觉有关。你最近有类似的感觉吗？”
        - 如果工具返回空的解释，你应该告诉用户你没有关于这个符号的具体信息，然后反问这个符号对他们个人而言意味着什么。

        对话目标:
        经过几轮交流后（通常是4-6个问题），当你感觉用户已经探讨了梦境的核心要素时，主动提出为他们做一个简短的总结，概述你们的对话和可能发现的见解。最后以支持和鼓励的语气结束对话。
        """
    )
    // ▲▲▲ 修改结束 ▲▲▲
    
    @StateObject private var aiEngine = AIEngine(configuration: dreamInterpreterConfig)
    @StateObject private var chatSession: ChatSession

    init() {
        let engine = AIEngine(configuration: Self.dreamInterpreterConfig)
        _aiEngine = StateObject(wrappedValue: engine)
        _chatSession = StateObject(wrappedValue: engine.startChatSession(with: [
                    .init(role: .assistant, content: "你好，我是你的解梦师。准备好后，请随时开始描述你的梦境，我会在这里倾听和引导。")
                ]))
    }
    
    var body: some View {
        ChatView(aiEngine: aiEngine, chatSession: chatSession)
            // 你可以为这个视图设置一个更具体的导航标题
            .navigationTitle("AI 解梦师")
    }
}
