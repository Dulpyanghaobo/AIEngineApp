//
//  AIEngineConfiguration.swift
//  pdfexportapp
//
//  Created by i564407 on 9/28/25.
//

import Foundation
import FoundationModels

public struct AIEngineConfiguration {
    /// 模型的用例（例如通用或内容标签）。
    public var useCase: SystemLanguageModel.UseCase
    /// 可选的自定义适配器。
    public var adapter: SystemLanguageModel.Adapter?
    /// 在会话中可用的工具列表。
    public var tools: [any Tool]
    /// 默认的系统指令。
    public var defaultInstructions: String

    public init(
        useCase: SystemLanguageModel.UseCase = .general,
        adapter: SystemLanguageModel.Adapter? = nil,
        tools: [any Tool] = [],
        defaultInstructions: String = "You are a helpful assistant."
    ) {
        self.useCase = useCase
        self.adapter = adapter
        self.tools = tools
        self.defaultInstructions = defaultInstructions
    }
    
    public static var `default`: AIEngineConfiguration {
        AIEngineConfiguration()
    }
    
    public static var contentTagger: AIEngineConfiguration {
        AIEngineConfiguration(useCase: .contentTagging, defaultInstructions: "You are an expert at tagging content.")
    }
}
