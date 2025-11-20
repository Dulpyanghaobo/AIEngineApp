//
//  ContactsService.swift
//  AIEngineApp
//

import Foundation
import Contacts

struct ContactInfo: Codable {
    var identifier: String
    var fullName: String
    var givenName: String
    var familyName: String
    var organizationName: String
    var phoneNumbers: [String]
    var emailAddresses: [String]
}

struct ContactsService {

    func search(keyword: String) async -> [ContactInfo] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else {
            print("🔍 [ContactsService] Empty keyword")
            return []
        }

        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            print("⚠️ [ContactsService] No contact permission.")
            return []
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let predicate = CNContact.predicateForContacts(matchingName: kw)

        do {
            let contacts = try store.unifiedContacts(
                matching: predicate,
                keysToFetch: keys
            )

            print("📒 [ContactsService] Found \(contacts.count) contacts for keyword: \(kw)")

            return contacts.map { c in
                ContactInfo(
                    identifier: c.identifier,
                    fullName: [c.givenName, c.familyName].joined(separator: " "),
                    givenName: c.givenName,
                    familyName: c.familyName,
                    organizationName: c.organizationName,
                    phoneNumbers: c.phoneNumbers.map { $0.value.stringValue },
                    emailAddresses: c.emailAddresses.map { $0.value as String }
                )
            }
        } catch {
            print("❌ [ContactsService] Error: \(error)")
            return []
        }
    }
}
