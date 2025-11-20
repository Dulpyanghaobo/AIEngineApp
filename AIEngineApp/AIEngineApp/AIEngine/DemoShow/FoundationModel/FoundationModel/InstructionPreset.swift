//
//  InstructionPreset.swift
//  AIEngineApp
//

import Foundation
import FoundationModels

/// 一个可复用的“指令模板”
/// - 内部存储多行指令文本
/// - 提供：
///   1. 真正的 Instructions 对象（用 Instructions { … } DSL 构建）
///   2. 文本预览
///   3. 可拷贝的 Swift 示例代码片段
struct InstructionTemplate {
    let lines: [String]

    /// 1) 真正传给 LanguageModelSession 的 Instructions
    func makeInstructions() -> Instructions {
        Instructions {
            for line in lines {
                line
            }
        }
    }

    /// 2) Plain text 预览（在 UI 里展示当前指令内容）
    var textPreview: String {
        lines.joined(separator: "\n")
    }

    /// 3) 示例代码片段：展示 Instructions { … } 的 DSL 用法
    var builderSnippet: String {
        let body = lines
            .map { line in
                let escaped = line.replacingOccurrences(of: "\"", with: "\\\"")
                return "    \"\(escaped)\""
            }
            .joined(separator: "\n")

        return """
        let instructions = Instructions {
        \(body)
        }

        let session = LanguageModelSession(instructions: instructions)
        """
    }
}

/// 端侧 Foundation Model 的系统指令预设（角色 / 模式）
enum InstructionPreset: String, CaseIterable, Identifiable {
    case writingAssistant
    case summarizer
    case searchSuggestionHelper
    case safeCritic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .writingAssistant:        return "Writing assistant"
        case .summarizer:              return "Summarizer"
        case .searchSuggestionHelper:  return "Search helper"
        case .safeCritic:              return "Safe critic"
        }
    }

    /// 根据当前“能力 + 参数”生成一个复用的指令模板
    /// - Parameters:
    ///   - capability: 当前选中的 Demo 能力（Summarize / Extract 等）
    ///   - maxSentences: 要求模型输出最多多少句
    ///   - strictSafety: 是否开启严格安全策略
    func template(
        maxSentences: Int,
        strictSafety: Bool
    ) -> InstructionTemplate {
        switch self {
        case .writingAssistant:
            var lines: [String] = []
            lines.append("Answer in the same language as the prompt.")
            lines.append("Be concise and clear.")
            lines.append("Improve grammar and style when appropriate.")
            lines.append("Keep your answer more than \(maxSentences) sentences.")
            if strictSafety {
                lines.append("If the user asks for something unsafe, respond with: \"I can't help with that.\"")
            }
            return InstructionTemplate(lines: lines)

        case .summarizer:
            var lines: [String] = []
            lines.append("You are a professional summarization assistant.")
            lines.append("Your main task is to summarize the given text.")
            lines.append("Focus on key facts and main ideas.")
            lines.append("Prefer bullet points when the text is long.")
            lines.append("Keep your answer within \(maxSentences) sentences.")
            if strictSafety {
                lines.append("Avoid giving legal, medical, or financial advice. If asked, say: \"I can't help with that.\"")
            }
            return InstructionTemplate(lines: lines)

        case .searchSuggestionHelper:
            var lines: [String] = []
            lines.append("You help the user generate search suggestions.")
            lines.append("Given the user's topic, suggest 5 short search queries.")
            lines.append("Each query should be between 3 and 7 words.")
            lines.append("Cover different angles of the same topic.")
            lines.append("Do not add explanations, only list the queries.")
            if strictSafety {
                lines.append("If the topic is harmful or unsafe, say: \"I can't help with that.\"")
            }
            return InstructionTemplate(lines: lines)

        case .safeCritic:
            var lines: [String] = []
            lines.append("You are a careful and safe content critic.")
            lines.append("First, briefly summarize the content in one sentence.")
            lines.append("Then judge if the content is harmful, hateful, or unsafe.")
            lines.append("Keep the explanation within \(maxSentences) sentences.")
            lines.append("If it is safe, say: \"Content appears safe.\"")
            lines.append("If it is not safe, say: \"Content appears unsafe. I can't help with that.\"")
            return InstructionTemplate(lines: lines)
        }
    }
}
