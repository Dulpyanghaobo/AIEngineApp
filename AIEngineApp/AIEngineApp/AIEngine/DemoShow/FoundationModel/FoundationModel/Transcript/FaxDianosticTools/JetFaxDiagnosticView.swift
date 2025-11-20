//
//  JetFaxDiagnosticView.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import SwiftUI
import FoundationModels

struct JetFaxDiagnosticView: View {
    @State private var viewModel = JetFaxDiagnosticViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // 输入区
                VStack(alignment: .leading, spacing: 8) {
                    Text("传真故障排查")
                        .font(.title2.bold())
                    
                    TextField("输入传真 ID，例如 FAX-20251119-001", text: $viewModel.faxId)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("描述你的问题", text: $viewModel.question, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    
                    Button {
                        Task { await viewModel.runDiagnostics() }
                    } label: {
                        HStack {
                            if viewModel.isRunning {
                                ProgressView()
                            }
                            Text(viewModel.isRunning ? "诊断中…" : "开始诊断")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunning || viewModel.faxId.isEmpty)
                }
                .padding()
                
                Divider()
                
                // Transcript 时间线区域
                if let session = viewModel.session {
                    HistoryTimelineView(transcript: session.transcript)
                } else {
                    Text("AI 会话尚未就绪…")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("JetFax AI 诊断")
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
