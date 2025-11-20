import Foundation
import FoundationModels
import Combine
import os.log

@MainActor
public class ChatSession: ObservableObject {

    @Published public private(set) var history: [ChatMessage]
    @Published public private(set) var isResponding: Bool = false
    
    private let session: LanguageModelSession

    init(
        systemModel: SystemLanguageModel,
        instructions: String,
        tools: [any Tool],
        history: [ChatMessage]
    ) {
        self.history = history
        self.session = LanguageModelSession(
            model: systemModel,
            tools: tools, instructions: instructions
        )
    }

    /// 发送一条新消息并获取流式响应。
    /// - Parameter prompt: 用户发送的消息文本。
    /// - Returns: 一个异步的、包含部分生成结果字符串的流。
    public func sendMessage(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        isResponding = true
        // 1. 将用户的消息添加到历史记录中
        history.append(.init(role: .user, content: prompt))

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: prompt)
                    
                    // 2. 遍历从模型返回的每一个“快照”
                    for try await snapshot in stream {
                        // 3. 将快照中的部分生成内容 (partial string) 直接传递出去
                        continuation.yield(snapshot.content)
                    }
                    
                    // 4. 流结束，通知调用方
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AIEngineError.generationFailed(underlyingError: error))
                }
                self.isResponding = false
            }
        }
    }
    
    // MARK: - Public History Management
    
    /// 公开方法，允许外部安全地向历史记录中添加消息。
    public func addMessage(_ message: ChatMessage) {
        history.append(message)
    }
    
    /// 公开方法，用于更新指定ID消息的内容（主要用于流式显示）。
    public func updateMessageContent(id: UUID, newContent: String) {
        if let index = history.firstIndex(where: { $0.id == id }) {
            history[index].content = newContent
        }
    }
}
