//
//  SearchContactTool.swift
//

import Foundation
import FoundationModels

struct SearchContactTool: Tool {
    let name = "searchContact"
    let description = "根据姓名搜索通讯录并返回可能的联系人列表"

    let contacts: ContactsService

    @Generable
    struct Args {
        var name: String
    }

    @Generable
    struct Output {
        var results: [ContactResult]

        @Generable
        struct ContactResult {
            var fullName: String
            var phoneNumbers: [String]
            var emails: [String]
        }
    }

    func call(arguments: Args) async throws -> Output {
        let list = await contacts.search(keyword: arguments.name)

        let mapped = list.map {
            Output.ContactResult(
                fullName: $0.fullName,
                phoneNumbers: $0.phoneNumbers,
                emails: $0.emailAddresses
            )
        }

        print("🔍 [SearchContactTool] 返回 \(mapped.count) 条搜索结果")

        return Output(results: mapped)
    }
}
