//
//  LookupContactTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import Foundation
import Contacts
import FoundationModels

/// 一个可以从 iOS 通讯录中查找联系人的 Tool。
///
/// 模型调用时会得到结构化的联系人信息（姓名 / 公司 / 电话 / 邮箱），
/// 方便它在回答里“打印出来”。
struct LookupContactTool: Tool {
    let name = "lookupContact"
    let description = "Searches user's contacts by name or organization and returns detailed contact info."

    // MARK: - Arguments ----------------------------------------------------

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        @Guide(description: "Keyword for matching contacts")
        var keyword: String
    }

    // MARK: - Output structures -------------------------------------------

    /// 单个联系人的详细信息，供模型后续使用 / 打印。
    @Generable
    struct ContactInfo: PromptRepresentable {
        /// CNContact.identifier，方便后续做二次操作（比如发传真时复用）
        var identifier: String

        var fullName: String
        var givenName: String
        var familyName: String

        var organizationName: String
        var phoneNumbers: [String]
        var emailAddresses: [String]
    }

    @Generable
    struct Result: PromptRepresentable {
        /// 匹配到的联系人列表（结构化）
        var contacts: [ContactInfo]

        /// 匹配数量
        var count: Int

        /// 如果需要，工具可以返回一个提示信息（例如权限问题）
        var note: String?
    }

    // MARK: - Tool main logic ---------------------------------------------

    func call(arguments: Arguments) async throws -> Result {
        let keyword = arguments.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return Result(contacts: [], count: 0, note: "Empty keyword.")
        }

        // 检查通讯录权限（实际 App 里最好提前请求权限，这里只做兜底）
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            let msg = "Contacts permission not granted. Please enable access in Settings."
            return Result(contacts: [], count: 0, note: msg)
        }

        let store = CNContactStore()

        // 需要读取的字段
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        // 按姓名匹配（包含名 / 姓）
        let predicate = CNContact.predicateForContacts(matchingName: keyword)
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

        let mapped: [ContactInfo] = contacts.map { contact in
            let given = contact.givenName
            let family = contact.familyName

            let namePart = [given, family]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            let fullName = namePart.isEmpty ? "(No Name)" : namePart

            let org = contact.organizationName

            let phones = contact.phoneNumbers
                .map { $0.value.stringValue }
                .filter { !$0.isEmpty }

            let emails = contact.emailAddresses
                .map { $0.value as String }
                .filter { !$0.isEmpty }

            return ContactInfo(
                identifier: contact.identifier,
                fullName: fullName,
                givenName: given,
                familyName: family,
                organizationName: org,
                phoneNumbers: phones,
                emailAddresses: emails
            )
        }

        return Result(
            contacts: mapped,
            count: mapped.count,
            note: mapped.isEmpty ? "No contacts found for keyword \(keyword)." : nil
        )
    }
}
