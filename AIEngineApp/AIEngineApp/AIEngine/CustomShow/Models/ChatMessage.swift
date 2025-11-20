//
//  ChatMessage.swift
//  pdfexportapp
//
//  Created by i564407 on 9/28/25.
//
import Foundation

public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let role: Role
    public var content: String
    
    public enum Role {
        case user
        case assistant
    }
    
    public init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}
