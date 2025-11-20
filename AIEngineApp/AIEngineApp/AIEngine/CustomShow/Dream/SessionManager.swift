//
//  SessionManager.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


// DreamJournalView.swift
// (用此文件替换 ChatView.swift)

import SwiftUI
import Combine
import os.log

// MARK: - 状态管理器
@MainActor
class SessionManager: ObservableObject {
    @Published var journalSession: DreamJournalSession?
    let aiEngine: AIEngine
    
    init(aiEngine: AIEngine) {
        self.aiEngine = aiEngine
    }
    
    func startSession(with dreamType: DreamType) {
        let session = DreamJournalSession(aiEngine: aiEngine, dreamType: dreamType)
        self.journalSession = session
        session.start()
    }
    
    func endSession() {
        self.journalSession = nil
    }
}

public struct DreamJournalView: View {
    @EnvironmentObject var sessionManager: SessionManager
    // @StateObject private var sessionManager = SessionManager(aiEngine: AIEngine())

    @Namespace private var ns

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {

            // ——— 选择区（同一屏内，开始后折叠隐藏） ———
            DreamTypeSelectorInlineSection()
                .zIndex(1)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .scale)))
                .opacity(sessionManager.journalSession == nil ? 1 : 0)
                .frame(maxHeight: sessionManager.journalSession == nil ? .infinity : 0, alignment: .top)
                .clipped()
                .animation(.easeInOut(duration: 0.25), value: sessionManager.journalSession != nil)

            // 分割线（有会话时隐藏）
            if sessionManager.journalSession == nil {
                Divider().padding(.vertical, 8)
            }

            // ——— 聊天区（同一屏内，开始后展开） ———
            Group {
                if let session = sessionManager.journalSession {
                    DreamChatInterfaceView(session: session)
                        .id(ObjectIdentifier(session)) // 强制切换时重建布局
                } else {
                    // 占位/可用性提示（不阻断）
                    AvailabilityHintView()
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity))
            .animation(.easeInOut(duration: 0.25), value: sessionManager.journalSession != nil)
        }
        .navigationTitle("梦境日记")
        .onAppear { sessionManager.aiEngine.checkAvailability() }
    }
}

// MARK: - 内联的“选择类型”区（同屏）
private struct DreamTypeSelectorInlineSection: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedDreamType: DreamType = .happy

    var body: some View {
        VStack(spacing: 20) {
            Text("你做了一个什么样的梦？")
                .font(.title2).fontWeight(.semibold)
                .padding(.top, 16)

            Picker("选择梦的类型", selection: $selectedDreamType) {
                ForEach(DreamType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    sessionManager.startSession(with: selectedDreamType)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("开始记录")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - 可用性提示（不阻断创建会话）
private struct AvailabilityHintView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        switch sessionManager.aiEngine.state {
        case .checkingAvailability:
            VStack(spacing: 12) {
                ProgressView("正在检查 AI 引擎可用性…")
                Text("你仍可先选择梦境类型并开始记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()

        case .available:
            // 没有会话且可用时，给个轻提示
            VStack(spacing: 8) {
                Text("准备好开始你的梦境记录吧")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

        case .unavailable(let reason):
            VStack(spacing: 10) {
                ContentUnavailableView(
                    "AI 目前不可用",
                    systemImage: "exclamationmark.triangle",
                    description: Text(reason)
                )
                Text("你仍然可以开始并先记录文字内容。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}


// MARK: - 子视图：聊天界面
struct DreamChatInterfaceView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var session: DreamJournalSession
    @State private var userInput: String = ""
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // 遍历并显示所有消息
                    ForEach(session.messages) { message in
                         DreamChatMessageView(message: message)
                             .id(message.id)
                    }
                }
                .onChange(of: session.messages) { _, newMessages in
                    // 自动滚动到最新消息
                    if let lastMessage = newMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 输入区域
            HStack {
                TextField("输入你的回答...", text: $userInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(5)
                    .focused($isTextEditorFocused)
                    // 关键改动：禁用状态由 DreamJournalSession 控制
                    .disabled(session.isThinking || session.isComplete)

                if session.isThinking {
                    ProgressView().padding(.horizontal)
                } else if session.isComplete {
                     Button("完成") {
                        sessionManager.endSession()
                     }
                     .buttonStyle(.bordered)
                } else {
                    Button(action: submit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                    }
                    .disabled(userInput.isEmpty || session.isThinking)
                }
            }
        }
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextEditorFocused = false
                }
            }
        }
    }
    
    private func submit() {
        let prompt = userInput
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        userInput = ""
        
        // 关键改动：调用梦境会话的专属提交方法
        session.submitAnswer(prompt)
    }
}

// MARK: - 辅助视图：单条消息
struct DreamChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 50) }
            
            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    Text("梦境助手")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
            }
            .padding(12)
            .background(message.role == .user ? Color.accentColor : Color(UIColor.secondarySystemBackground))
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            if message.role == .assistant { Spacer(minLength: 50) }
        }
    }
}
