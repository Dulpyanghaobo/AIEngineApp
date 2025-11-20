import Foundation
import FoundationModels
import Combine

/// 负责管理和调用Apple Foundation Models的核心引擎。
/// A main actor to ensure thread-safe operations on the model and sessions.
@MainActor
public class AIEngine: ObservableObject {

    /// 引擎的当前状态，可供UI层订阅。
    @Published public private(set) var state: AIEngineState = .available

    private var systemModel: SystemLanguageModel
    private let configuration: AIEngineConfiguration

    /// 初始化AIEngine。
    /// - Parameter configuration: 引擎的配置，如用例、适配器等。
    public init(configuration: AIEngineConfiguration = .default) {
        self.configuration = configuration
        
        // 根据配置初始化系统模型
        if let adapter = configuration.adapter {
            self.systemModel = SystemLanguageModel(adapter: adapter)
        } else {
            self.systemModel = SystemLanguageModel(useCase: configuration.useCase)
        }
    }

    /// 检查底层模型的可用性，并更新状态。
    /// 必须在使用引擎前调用此方法。
    public func checkAvailability() {
        state = .checkingAvailability
        switch systemModel.availability {
        case .available:
            state = .available
        case .unavailable(let reason):
            // CHANGED: Using a more descriptive string for the reason instead of hashValue.
            state = .unavailable(reason: String(describing: reason))
        }
    }

    @MainActor
    public func generateResponse(for prompt: String, with instructions: String? = nil) -> AsyncThrowingStream<String, Error> {
        guard state == .available else {
            return AsyncThrowingStream {
                $0.finish(throwing: AIEngineError.modelNotAvailable)
            }
        }

        let sessionInstructions = instructions ?? configuration.defaultInstructions
        let session = LanguageModelSession(tools: configuration.tools, instructions: sessionInstructions)

        let responseStream = session.streamResponse(to: prompt)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var acc = "" // DELTA: keep last full snapshot
                    for try await snapshot in responseStream {
                        let full = snapshot.content
                        // DELTA: yield only the new suffix beyond the common prefix
                        let common = acc.commonPrefix(with: full)
                        let delta = String(full.dropFirst(common.count))
                        if !delta.isEmpty {
                            continuation.yield(delta)
                            acc = full
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 为单个Prompt生成流式结构化数据（遵循Generable协议）。
    /// - Parameters:
    ///   - prompt: 用户的输入提示。
    ///   - type: 你期望生成的Swift数据类型。
    /// - Returns: 一个异步的、部分生成的结构化数据流。
    public func generate<T: Generable>(structuredResponseFor prompt: String, ofType type: T.Type) -> AsyncThrowingStream<T.PartiallyGenerated, Error> {
        guard state == .available else {
            return AsyncThrowingStream {
                $0.finish(throwing: AIEngineError.modelNotAvailable)
            }
        }

        let session = LanguageModelSession(tools: configuration.tools, instructions: configuration.defaultInstructions)

        // FIX: Replaced non-existent `generate` with `streamResponse`.
        let responseStream = session.streamResponse(to: prompt, generating: type)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await snapshot in responseStream {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// 为单个 Prompt 生成一次性的结构化数据（Generable 类型）。
    /// - Parameters:
    ///   - prompt: 给模型的自然语言指令。
    ///   - type: 期望生成的 Swift 结构体类型（@Generable）。
    /// - Returns: 完整的结构化结果对象。
    public func generateOnce<T: Generable>(
        structuredResponseFor prompt: String,
        of type: T.Type
    ) async throws -> T {
        guard state == .available else {
            throw AIEngineError.modelNotAvailable
        }

        let session = LanguageModelSession(
            tools: configuration.tools,
            instructions: configuration.defaultInstructions
        )

        let response = try await session.respond(
            to: prompt,
            generating: type
        )

        return response.content
    }

    /// 启动一个新的多轮聊天会话。
    /// - Parameters:
    ///   - history: 可选的初始聊天记录。
    ///   - instructions: 本次会话的特定指令，如果为nil则使用默认指令。
    /// - Returns: 一个ChatSession实例，用于管理该次对话。
    public func startChatSession(with history: [ChatMessage] = [], instructions: String? = nil) -> ChatSession {
        // 使用传入的指令，如果为nil，则回退到配置中的默认指令。
        let sessionInstructions = instructions ?? configuration.defaultInstructions
        return ChatSession(
            systemModel: self.systemModel,
            instructions: sessionInstructions,
            tools: configuration.tools,
            history: history
        )
    }
}
