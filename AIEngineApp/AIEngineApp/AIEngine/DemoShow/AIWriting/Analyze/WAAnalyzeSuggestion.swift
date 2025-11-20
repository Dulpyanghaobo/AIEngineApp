import Foundation

struct WAAnalyzeSuggestion: Identifiable, Equatable {
    let id = UUID()
    let originalSentence: String
    let suggestedSentence: String
    var handled: Bool = false
}

enum WAAnalyzePhase {
    case loading
    case suggestions
    case done
}
