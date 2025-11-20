import SwiftUI
import FoundationModels

struct AIHubDemoView: View {

    @State private var engine: AIHubEngine?
    @State private var userInput: String = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let engine {
                    JetAIHubConversationView(engine: engine, userInput: $userInput)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在启动 Jet AI 中枢…")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .task {
            if engine == nil {
                engine = try? await AIHubEngine()
            }
        }
    }
}

// MARK: - 主对话区域

struct JetAIHubConversationView: View {

    @Bindable var engine: AIHubEngine
    @Binding var userInput: String

    var body: some View {
        VStack(spacing: 12) {

            // 标题 + 状态
            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jet AI 中枢")
                        .font(.headline)
                    Text("自动编排传真 & 文档工作流")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(engine.isProcessing ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(engine.isProcessing ? "处理中…" : "就绪")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 气泡工作流区域
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                VStack(spacing: 8) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(engine.transcript) { entry in
                                    TranscriptBubbleRow(entry: entry)
                                        .id(entry.id)
                                }

                                // 流式中的 AI 临时气泡
                                if !engine.streamingResponse.isEmpty {
                                    AIBubbleView(text: engine.streamingResponse, isStreaming: true)
                                }
                            }
                            .padding(12)
                        }
                        .onChange(of: engine.transcript.count) { _ in
                            // 每次 transcript 更新自动滚到底部
                            if let last = engine.transcript.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 380)

            // 输入栏
            JetAIInputBar(
                text: $userInput,
                isProcessing: engine.isProcessing,
                onSend: { text in
                    Task {
                        await engine.handleUserUtterance(text)
                    }
                    userInput = ""
                }
            )
        }
    }
}

// MARK: - ChatGPT 风格输入栏

struct JetAIInputBar: View {
    @Binding var text: String
    var isProcessing: Bool
    var onSend: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("对 JetAI 说点什么…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            Button {
                let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else { return }
                onSend(content)
            } label: {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
    }
}

// MARK: - Transcript → 气泡映射

struct TranscriptBubbleRow: View {
    let entry: Transcript.Entry

    var body: some View {
        switch entry {
        case .instructions:
            // 只在最开始出现一次，可以做成一条浅色系统提示
            SystemBubbleView(text: "Jet AI 中枢已加载指令与工具。")

        case .prompt(let prompt):
            let text = prompt.segments
                .compactMap { segment -> String? in
                    if case let .text(ts) = segment { return ts.content }
                    return nil
                }
                .joined()
            if !text.isEmpty {
                UserBubbleView(text: text)
            }

        case .response(let response):
            let text = response.segments
                .compactMap { segment -> String? in
                    if case let .text(ts) = segment { return ts.content }
                    return nil
                }
                .joined()
            if !text.isEmpty {
                AIBubbleView(text: text, isStreaming: false)
            }

        case .toolCalls(let calls):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(calls.enumerated()), id: \.offset) { _, call in
                    ToolCallBubbleView(toolName: call.toolName,
                                       argumentsDescription: call.arguments.debugDescription)
                }
            }

        case .toolOutput(let output):
            let content = output.segments
                .map { $0.description }
                .joined(separator: " | ")
            ToolOutputBubbleView(toolName: output.toolName,
                                 outputDescription: content)
        }
    }
}

// MARK: - 各种气泡组件

/// 用户（右侧）气泡
struct UserBubbleView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor)
                )
        }
    }
}

/// AI（左侧）气泡
struct AIBubbleView: View {
    let text: String
    var isStreaming: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.subheadline)
                if isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("生成中…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            Spacer()
        }
    }
}

/// 系统提示气泡（中间偏左）
struct SystemBubbleView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                )
            Spacer()
        }
    }
}

/// 工具调用气泡：带 Tool badge + JSON 参数
struct ToolCallBubbleView: View {
    let toolName: String
    let argumentsDescription: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(toolName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                    Text("Tool Call")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(argumentsDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

/// 工具输出气泡：带 Tool badge + 输出摘要
struct ToolOutputBubbleView: View {
    let toolName: String
    let outputDescription: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(toolName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                    Text("Tool Output")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(outputDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
