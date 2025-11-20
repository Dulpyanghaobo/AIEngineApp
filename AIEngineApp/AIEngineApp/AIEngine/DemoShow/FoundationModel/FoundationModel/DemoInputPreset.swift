enum DemoInputPreset: String, CaseIterable, Identifiable {
    case shortArticle
    case supportEmail
    case meetingNotes
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .shortArticle:
            return "短文章示例"
        case .supportEmail:
            return "客服邮件示例"
        case .meetingNotes:
            return "会议纪要示例"
        }
    }
    
    var sampleText: String {
        switch self {
        case .shortArticle:
            return """
            Apple today announced updates to its on-device language models, enabling developers to build private and low-latency AI features directly on iPhone, iPad, and Mac.
            """
        case .supportEmail:
            return """
            Hi team,

            I subscribed to your app last week but some Pro features are still locked. Could you check if my purchase was processed correctly?

            Best,
            Alex
            """
        case .meetingNotes:
            return """
            - Project: Fax growth plan
            - Attendees: Hab, PM, Marketing
            - Decisions:
              • Focus on “free fax” keyword for ASA
              • Improve onboarding to explain free pages and subscription
            """
        }
    }
}
