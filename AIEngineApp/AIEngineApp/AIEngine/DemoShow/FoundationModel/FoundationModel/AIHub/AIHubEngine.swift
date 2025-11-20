import SwiftUI
import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class AIHubEngine {

    private(set) var session: LanguageModelSession
    var transcript: Transcript { session.transcript }

    // Services
    private let faxService = FaxService()
    private let contactService = ContactsService()
    private let coverService = CoverPageService()

    // 用于日志打印的游标
    private var lastTranscriptIndex: Transcript.Index = 0

    // MARK: - UI 绑定状态

    /// 是否正在处理当前用户指令
    var isProcessing: Bool = false

    /// 模型当前流式生成中的文本（未最终落入 transcript 的 response）
    var streamingResponse: String = ""

    init() async throws {

        // 1. 工具注册（✅ 新工具加进来）
        let tools: [any Tool] = [
            SendFaxTool(fax: faxService),
            SearchContactTool(contacts: contactService),
            AddCoverPageTool(cover: coverService)
        ]

        // 2. Instructions 定义（模型的大脑）
        let instructions = Instructions {
            """
            你是 Jet AI 中枢（JetAIHub），负责处理与传真相关的所有智能工作流。

            --- 🛠 可用工具 ---
            你可以调用以下工具，它们是你所有能力的来源：

            1. searchContact  
               - 根据姓名 / 关键词查找用户的联系人  
               - 必须通过工具获取传真号码，不允许凭空编造

            2. addCoverPage  
               - 生成传真封面页  
               - coverText 必须来自用户明确提供的内容或你向用户确认后的内容

            3. sendFax  
               - 发送传真（文档 + 号码 + 封面等信息）  
               - 属于“不可逆操作”，调用前必须获得用户确认

            --- 🧠 你的角色 ---
            你是一个面向用户的“AI 工作流协调器”。  
            你需要理解用户意图、规划步骤、决定需要调用哪些工具，并保持整个流程专业、透明、可控。
            """
        }

        // 3. 创建 session
        self.session = LanguageModelSession(
            model: .default,
            tools: tools,
            instructions: instructions
        )
    }

    // MARK: - 对外入口：处理用户一句话

    func handleUserUtterance(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let prompt = Prompt { trimmed }

        isProcessing = true
        streamingResponse = ""

        do {
            let stream = session.streamResponse(
                to: prompt,
                options: .init(
                    sampling: .random(probabilityThreshold: 0.9),
                    temperature: 0.3,
                    maximumResponseTokens: 300
                )
            )

            for try await snapshot in stream {
                // 1️⃣ 流式文本（模型当前已经生成到哪）
                let partialText = snapshot.content
                if !partialText.isEmpty {
                    streamingResponse = partialText
                }

                // 2️⃣ 查看 transcript 里有没有新增事件（Prompt / Tool / Response）
                flushNewTranscriptEntries()
            }

        } catch {
            print("❌ 出错: \(error.localizedDescription)")
        }

        // 流式结束，最终内容会出现在 transcript 的 .response 里
        streamingResponse = ""
        isProcessing = false
    }

    // MARK: - 打印 Transcript 日志（仅用于控制台调试）

    private func flushNewTranscriptEntries() {
        let t = session.transcript
        guard lastTranscriptIndex < t.endIndex else { return }

        for idx in lastTranscriptIndex..<t.endIndex {
            let entry = t[idx]

            switch entry {
            case .instructions:
                // 一般只在 session 初始化时有一次，demo 里可以忽略
                break

            case .prompt(let p):
                let text = p.segments
                    .compactMap { segment -> String? in
                        if case let .text(ts) = segment { return ts.content }
                        return nil
                    }
                    .joined()
                print("🗣 用户输入: \(text)")

            case .toolCalls(let calls):
                for call in calls {
                    print("🔧 工具调用: \(call.toolName)")
                    print("   参数: \(call.arguments)")
                }

            case .toolOutput(let output):
                let content = output.segments
                    .map { $0.description }
                    .joined(separator: " | ")
                print("📤 工具输出: \(output.toolName)")
                print("   内容: \(content)")

            case .response(let r):
                let text = r.segments
                    .compactMap { segment -> String? in
                        if case let .text(ts) = segment { return ts.content }
                        return nil
                    }
                    .joined()
                print("💬 AI 回答完成片段: \(text)")
            }
        }

        // 标记我们已经处理到哪里了
        lastTranscriptIndex = t.endIndex
    }
}
