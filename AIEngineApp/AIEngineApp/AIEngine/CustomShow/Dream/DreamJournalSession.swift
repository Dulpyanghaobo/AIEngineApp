//
//  DreamJournalSession.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import Foundation
import Combine
import os.log

@MainActor
public class DreamJournalSession: ObservableObject {
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public private(set) var isThinking: Bool = false
    @Published public private(set) var isComplete: Bool = false
    
    private var questionCount = 0
    private let totalQuestions = 5
    
    private var chatSession: ChatSession
    private var cancellables = Set<AnyCancellable>()

    public init(aiEngine: AIEngine, dreamType: DreamType) {
        let dreamInstructions = """
        You are a gentle and insightful dream journal assistant. The user had a "\(dreamType.rawValue)".
        Your task is to help them explore their dream by asking them exactly \(totalQuestions) insightful questions.
        You must ask the questions ONE AT A TIME. Wait for the user to respond to a question before asking the next one.
        After you receive the answer to your \(totalQuestions)th question, you MUST stop asking questions and instead provide a concise summary of the dream based on the entire conversation.
        Start the summary with a title: "关于这个梦的总结：".
        Do not greet the user or use conversational filler. Your first response should be only the first question.
        """
        
        self.chatSession = aiEngine.startChatSession(instructions: dreamInstructions)
        
        self.chatSession.$history
            .assign(to: \.messages, on: self)
            .store(in: &cancellables)
            
        self.chatSession.$isResponding
            .assign(to: \.isThinking, on: self)
            .store(in: &cancellables)
    }

    /// 开始梦境记录流程，让AI提出第一个问题。
    public func start() {
        Task {
            await sendMessage("我做了一个开心的梦")
            questionCount = 1
        }
    }

    /// 提交用户的回答。
    public func submitAnswer(_ answer: String) {
        guard !answer.isEmpty, !isThinking, !isComplete else { return }
        
        if questionCount < totalQuestions {
            questionCount += 1
        } else {
            isComplete = true
        }
        
        Task {
            await sendMessage(answer)
        }
    }
    
    // DreamJournalSession.swift
    private func sendMessage(_ prompt: String) async {
        let assistantMessage = ChatMessage(role: .assistant, content: "")

        do {
            let stream = chatSession.sendMessage(prompt)
            chatSession.addMessage(assistantMessage)

            var fullResponse = ""

            for try await token in stream {
                if token.hasPrefix(fullResponse) {
                    // 本帧是完整快照（cumulative snapshot）
                    fullResponse = token
                } else {
                    // 本帧是增量（delta）
                    fullResponse.append(token)
                }

                // （可选）去掉少数模型重复首尾的空格/换行抖动
                // while fullResponse.hasSuffix("\n\n\n") { fullResponse.removeLast() }

                chatSession.updateMessageContent(id: assistantMessage.id, newContent: fullResponse)
            }
        } catch {
            if let lastMessage = chatSession.history.last, lastMessage.role == .assistant {
                chatSession.updateMessageContent(id: lastMessage.id, newContent: "抱歉，我遇到了一个错误。")
            }
        }
    }

}
