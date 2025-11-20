import Foundation
import FoundationModels

/// 描述从传真封面页中抽取出的结构化信息。
@Generable(description: "Structured fax cover sheet metadata extracted from a fax attachment page.")
struct FaxEntities {

    /// 传真总页数，例如 "Page 14 pages" -> 14；如果缺失则为 nil。
    @Guide(description: "The total number of pages in the fax, if present. For example, 'Page 14 pages' should be extracted as 14.")
    var pageCount: Int? = nil

    /// 传真日期，保持原文格式，例如 "11/06/2025"。
    @Guide(description: "The date of the fax as it appears in the text, such as '11/06/2025'.")
    var faxDate: String? = nil

    /// 收件人（TO）姓名。
    @Guide(description: "The recipient's name in the 'TO' section of the fax cover.")
    var toName: String? = nil

    /// 收件人（TO）电话号码。
    @Guide(description: "The recipient's phone number in the 'TO' section.")
    var toPhone: String? = nil

    /// 发件人（FROM）姓名。
    @Guide(description: "The sender's name in the 'FROM' section.")
    var fromName: String? = nil

    /// 发件人（FROM）电话号码。
    @Guide(description: "The sender's phone number in the 'FROM' section.")
    var fromPhone: String? = nil

    /// 发件人（FROM）邮箱。
    @Guide(description: "The sender's email address in the 'FROM' section, if any.")
    var fromEmail: String? = nil

    /// 传真主题（THEME），例如 "Loan #8200463906"。
    @Guide(description: "The main theme or subject of the fax, such as 'Loan #8200463906'.")
    var theme: String? = nil

    /// 备注内容（NOTES），如果为空可以是空字符串或 nil。
    @Guide(description: "Additional comments or notes in the 'NOTES' section. Use an empty string or nil if the notes section is blank.")
    var notes: String? = nil
}

// MARK: - 合并逻辑：后面的覆盖前面的

extension FaxEntities {
    /// 使用 new 覆盖当前实体中的字段：new 中非 nil 的字段会覆盖旧值
    mutating func merge(overridingWith new: FaxEntities) {
        if let v = new.pageCount { pageCount = v }
        if let v = new.faxDate   { faxDate  = v }
        if let v = new.toName    { toName   = v }
        if let v = new.toPhone   { toPhone  = v }
        if let v = new.fromName  { fromName = v }
        if let v = new.fromPhone { fromPhone = v }
        if let v = new.fromEmail { fromEmail = v }
        if let v = new.theme     { theme    = v }
        if let v = new.notes     { notes    = v }
    }
}
