import SwiftUI
import FoundationModels

/// 一个简单的 Transcript 可视化组件：
/// 垂直时间线展示 Instructions / Prompt / Tool 调用 / Tool 输出 / 模型回复。
struct HistoryTimelineView: View {
    let transcript: Transcript
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(zip(transcript.indices, transcript)), id: \.0) { index, entry in
                    TimelineEntryRow(index: index, entry: entry)
                }
            }
            .padding()
        }
    }
}

private struct TimelineEntryRow: View {
    let index: Int
    let entry: Transcript.Entry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间线上的小圆点
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                HStack {
                    Text("#\(index + 1) \(title)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(color)
                    Spacer()
                }
                
                if let summary = summaryText, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("(无可显示内容)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Derivatives
    
    private var title: String {
        switch entry {
        case .instructions:
            return "Instructions"
        case .prompt:
            return "Prompt (用户问题)"
        case .toolCalls:
            return "Tool 调用"
        case .toolOutput:
            return "Tool 输出"
        case .response:
            return "模型回复"
        }
    }
    
    private var color: Color {
        switch entry {
        case .instructions:
            return .blue
        case .prompt:
            return .green
        case .toolCalls:
            return .orange
        case .toolOutput:
            return .purple
        case .response:
            return .pink
        }
    }
    
    /// 把不同 entry 的内容简化成一段可读文本
    private var summaryText: String? {
        switch entry {
        case .instructions(let instructions):
            return text(from: instructions.segments)
            
        case .prompt(let prompt):
            return text(from: prompt.segments)
            
        case .toolCalls(let calls):
            if calls.isEmpty { return nil }
            let lines: [String] = calls.map { call in
                "• 调用 \(call.toolName) with arguments: \(String(describing: call.arguments))"
            }
            return lines.joined(separator: "\n")
            
        case .toolOutput(let output):
            let body = text(from: output.segments) ?? ""
            return "• \(output.toolName) 输出：\n\(body)"
            
        case .response(let response):
            return text(from: response.segments)
        }
    }
    
    private func text(from segments: [Transcript.Segment]) -> String? {
        let pieces: [String] = segments.compactMap { segment in
            switch segment {
            case .text(let textSegment):
                return textSegment.content
            case .structure(let structured):
                return "[\(structured.source)] \(String(describing: structured.content))"
            }
        }
        let joined = pieces.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }
}
