//
//  GenerableDemoScenario.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


enum GenerableDemoScenario: String, CaseIterable, Identifiable {
    case taxForm
    case employmentContract
    case medicalRecord
    case invoice
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .taxForm:           return "报税表 / 税务资料"
        case .employmentContract:return "劳动合同"
        case .medicalRecord:     return "就诊记录 / 医疗单据"
        case .invoice:           return "发票 / 账单"
        }
    }
    
    /// 模拟 OCR 完成后的文档文本
    var sampleOCRText: String {
        switch self {
        case .taxForm:
            return """
            Form 1040 U.S. Individual Income Tax Return 2024
            Filing Status: Single
            Taxpayer: John Doe, SSN XXX-XX-1234
            Wages, salaries, tips: 85,000
            Taxable interest: 120
            Total tax: 12,300
            Amount you owe: 1,250 due by April 15, 2025.
            """
        case .employmentContract:
            return """
            EMPLOYMENT AGREEMENT
            Employer: JetApps Inc.
            Employee: Alice Zhang
            Position: iOS Engineer, Full-time
            Confidentiality and IP assignment clauses included.
            Termination notice: 30 days in writing.
            Signed by both parties on 2025-10-20.
            """
        case .medicalRecord:
            return """
            Shanghai General Hospital Outpatient Record
            Patient: Wang Li, Female, Age 42
            Diagnosis: Type 2 Diabetes, follow-up visit.
            Doctor's advice: Continue Metformin 500mg, lab test every 3 months.
            Notes: Contains lab report and personal health history.
            """
        case .invoice:
            return """
            Invoice #2025-1101-08
            Vendor: Jet Cloud Storage Ltd.
            Customer: ABC Law Firm
            Service period: 2025-10-01 to 2025-10-31
            Total amount: $129.00
            Payment terms: Net 30 days, bank transfer only.
            """
        }
    }
}
