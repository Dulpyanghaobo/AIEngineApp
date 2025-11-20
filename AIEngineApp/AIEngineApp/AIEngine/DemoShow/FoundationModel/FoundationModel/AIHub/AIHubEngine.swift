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
    
    private let faxDatabase = FaxDatabaseService()
    private let faxEditService = FaxEditService()

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
            AddCoverPageTool(cover: coverService),

            SearchFaxTool(database: faxDatabase),
            SaveFaxDraftTool(database: faxDatabase),
            CropFaxTool(edit: faxEditService)
        ]

        // 2. Instructions 定义（模型的大脑）
        let instructions = Instructions {
            """
            你是 Jet AI 中枢（JetAIHub）。
            你可以通过调用工具来帮助用户处理传真和文档任务。

            你能做的事情：
            - 查找联系人 → searchContact
            - 生成封面页 → addCoverPage
            - 发送传真 → sendFax
            - 搜索历史传真/草稿 → searchFax
            - 将当前文档保存为草稿传真 → saveFaxDraft
            - 对文档指定页面进行裁剪 → cropFax

            通常的工作流示例：
            1. 用户说“帮我把这份 IRS 表格发给我的会计”：
               - 通过 searchContact 找到联系人号码
               - 如有需要，通过 addCoverPage 生成封面
               - 最后通过 sendFax 发送，并把价格和 faxId 告诉用户

            2. 用户说“看看我最近有没有发错的传真”：
               - 使用 searchFax 按关键词或状态筛选（比如 status = failed）

            3. 用户说“先把这份合同保存成草稿，我改一改再发”：
               - 使用 saveFaxDraft 保存草稿并返回 draftFaxId

            4. 用户说“帮我把第一页多余的空白裁掉再发”：
               - 先使用 cropFax 生成裁剪后的新文档ID
               - 再用新 documentId 调用 sendFax

            使用规则：
            1. 不能编造联系人号码、faxId、或文档信息，必须通过工具获取。
            2. 涉及发送传真等不可逆操作时必须先询问用户确认。
            3. 遇到“帮我搞定”时，可以自己规划工具调用顺序，但每一步都要向用户解释你做了什么。
            4. 工具调用序列必须专业、合规、顺序合理。
            5. 回复用户时先自然语言总结，再列出你完成了哪些步骤（以列表形式）。
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
