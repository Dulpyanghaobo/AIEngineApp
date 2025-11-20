// Enhanced DocumentWorkflowPlan with more complexity for demo
import SwiftUI
import Foundation
import FoundationModels

@Generable(description: "AI workflow plan for a scanned / faxed document with extended details.")
struct DocumentWorkflowPlan {

    // MARK: - Document Level Summary --------------------------------------------------
    @Guide(description: "Short title for this document, like 'IRS 1040 Tax Return'.")
    var title: String

    @Guide(
        description: "Main type of this document.",
        .anyOf([
            "Tax form", "Government form", "Medical record", "Legal contract",
            "Insurance claim", "Invoice", "Bank statement", "ID document", "Receipt", "Other"
        ])
    )
    var documentType: String

    @Guide(description: "Purpose or intent behind this document (e.g., filing taxes, onboarding, claim submission).")
    var purposeSummary: String

    @Guide(description: "Whether the document contains sensitive personal or financial info.")
    var containsSensitiveData: Bool

    @Guide(description: "Urgency score 1 (not urgent) to 5 (very urgent).", .range(1...5))
    var urgencyScore: Int

    @Guide(description: "Confidence score for model interpretation, 0.0 to 1.0.", .range(0.0...1.0))
    var confidenceScore: Double

    // MARK: - Document Structure Analysis --------------------------------------------

    @Guide(description: "Detected number of sections found in the document.", .range(1...20))
    var sectionCount: Int

    @Guide(description: "Detected key fields like Name, SSN, Address, Invoice#.", .maximumCount(20))
    var keyFields: [DetectedField]

    @Generable(description: "Key-value field extracted or inferred from OCR.")
    struct DetectedField: Equatable {
        @Guide(description: "Field name, like 'Name', 'SSN', 'Total Amount'.")
        var fieldName: String

        @Guide(description: "Extracted value from OCR.")
        var fieldValue: String

        @Guide(description: "True if field contains PII or sensitive info.")
        var isSensitive: Bool
    }

    // MARK: - Scan Recommendations ----------------------------------------------------

    @Guide(description: "Recommended scan color mode.")
    var recommendedColorMode: String

    @Guide(description: "Recommended DPI like 150, 300, 600.")
    var recommendedDPI: Int

    @Guide(description: "If PDF compression is recommended.")
    var shouldCompressPDF: Bool

    @Guide(description: "If deskewing, background removal, or edge enhancement is needed.")
    var imageCleanupChecklist: [String]

    // MARK: - Fax Recommendations -----------------------------------------------------

    @Guide(description: "Whether this document is suitable for fax.")
    var suitableForFax: Bool

    @Guide(description: "Estimated fax pages.", .range(1...100))
    var estimatedFaxPages: Int

    @Guide(description: "Whether to add a fax cover page.")
    var shouldAddFaxCover: Bool

    @Guide(description: "Fax priority suggestion, 1 to 3.", .range(1...3))
    var faxPriority: Int

    // MARK: - Workflow Risk Assessment ------------------------------------------------

    @Guide(description: "Warnings the user should know (e.g., missing signature, unclear photo).", .maximumCount(10))
    var warnings: [String]

    @Guide(description: "Potential errors before sending or storing.", .maximumCount(10))
    var potentialErrors: [String]

    // MARK: - Suggested Pipeline Steps ------------------------------------------------

    @Guide(description: "Recommended automated pipeline steps.", .maximumCount(10))
    var pipelineSteps: [PipelineStep]

    @Generable(description: "Represents an automated step in a document pipeline.")
    struct PipelineStep: Equatable {
        @Guide(description: "Identifier like 'ocr', 'enhance_image', 'generate_pdf'.")
        var identifier: String

        @Guide(description: "Human-readable title.")
        var title: String

        @Guide(description: "Short explanation.")
        var rationale: String
    }

    // MARK: - Next Actions ------------------------------------------------------------
    @Guide(description: "Recommended next actions for the user.", .maximumCount(10))
    var nextActions: [NextAction]

    @Generable(description: "User-facing next action.")
    struct NextAction: Equatable {
        @Guide(description: "Stable identifier.")
        var identifier: String

        @Guide(description: "Short actionable label.")
        var title: String

        @Guide(description: "Reason behind recommendation.")
        var rationale: String
    }
}
