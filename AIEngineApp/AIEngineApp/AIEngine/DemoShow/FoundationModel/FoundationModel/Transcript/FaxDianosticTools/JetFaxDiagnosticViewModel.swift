import SwiftUI
import Foundation
import FoundationModels
import Observation

/// JetFax 诊断 Demo：
/// - 使用真正的 `LanguageModelSession`
/// - 通过 Tool 模拟后端 JSON 返回
/// - 依靠 `session.transcript` 在 UI 中展示完整的对话 + 工具调用轨迹
@MainActor
@Observable
final class JetFaxDiagnosticViewModel {
    // MARK: - Public state (绑定到 JetFaxDiagnosticView)
    
    /// 当前语言模型会话
    var session: LanguageModelSession?
    
    /// 用户输入的传真 ID
    var faxId: String = ""
    
    /// 用户提出的问题
    var question: String = "这份传真为什么一直 pending，已经扣费但对方收不到？"
    
    /// 当前是否在诊断中（控制按钮 / loading）
    var isRunning: Bool = false
    
    /// 最近一次错误信息（如果有）
    var errorMessage: String?
    
    /// 最近一次模型给出的结论（可选：你可以在 UI 里展示）
    var lastSummary: String = ""
    
    // MARK: - 初始化
    
    init() {
        Task {
            await setupSession()
        }
    }
    
    // MARK: - Session 构建
    
    /// 创建真正的 LanguageModelSession，并把 Tool 挂上去
    func setupSession() async {
        do {
            let model = SystemLanguageModel.default
            
            // 可用的工具：模拟后端 JSON
            let tools: [any Tool] = [
                FetchFaxStatusTool(),
                FetchBillingInfoTool()
            ]
            
            // 说明模型的角色 & workflow
            let instructions = Instructions {
                """
                你是 JetFax 内置的“发送失败诊断助手”。

                你可以调用两个工具来模拟访问后端 JSON：
                1. fetchFaxStatus —— 根据 faxId 查询传真状态、网关错误码等。
                2. fetchBillingInfo —— 根据 faxId 查询计费是否成功、扣费金额。

                使用流程建议：
                - 总是先调用 fetchFaxStatus。
                - 如果状态是 failed 或 pending，再调用 fetchBillingInfo 看是否已经扣费。
                - 调用完工具后，用简洁的中文总结问题原因和给用户的下一步建议。
                - 结论里尽量引用一些关键字段（例如 status、errorCode、gateway）。
                """
            }
            
            let newSession = LanguageModelSession(
                model: model,
                tools: tools,
                instructions: instructions
            )
            
            await MainActor.run {
                self.session = newSession
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "初始化语言模型失败：\(error)"
            }
        }
    }
    
    // MARK: - 对外方法：启动一次诊断
    
    func runDiagnostics() async {
        guard let session else {
            errorMessage = "语言模型未准备好，请稍后重试。"
            return
        }
        
        errorMessage = nil
        isRunning = true
        
        do {
            let userQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
            let faxIdText = faxId.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let prompt = Prompt {
                """
                用户希望你帮忙诊断某次传真发送问题，并解释原因、给出下一步建议。
                请根据工具返回的 JSON 数据进行分析，而不是自己虚构数据。
                
                - 用户输入的传真 ID: \(faxIdText.isEmpty ? "（用户未填写，使用 demo id FAX-DEMO-001）" : faxIdText)
                - 用户描述的问题: \(userQuestion.isEmpty ? "（用户未补充描述，按常见“已扣费但没送达”场景处理）" : userQuestion)
                """
            }
            
            let options = GenerationOptions(
                sampling: .random(probabilityThreshold: 0.8),
                temperature: 0.4,
                maximumResponseTokens: 300
            )
            
            let response = try await session.respond(to: prompt, options: options)
            
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                lastSummary = text
            }
        } catch {
            errorMessage = "诊断过程中出错：\(error)"
        }
        
        isRunning = false
    }
}
