//
//  Plugin.swift
//
//
//  Created by Jonathan Gerber on 15.02.20.
//  Copyright © 2020 Byrds & Bytes GmbH. All rights reserved.
//

import Foundation
import Capacitor
import Contacts

@objc(ContactsPlugin)
public class ContactsPlugin: CAPPlugin {

    private let birthdayFormatter = DateFormatter()

    override public func load() {
        // You must set the time zone from your default time zone to UTC +0,
        // which is what birthdays in Contacts are set to.
        birthdayFormatter.timeZone = TimeZone(identifier: "UTC")
        birthdayFormatter.dateFormat = "YYYY-MM-dd"
    }

    @objc func getPermissions(_ call: CAPPluginCall) {
        print("checkPermission was triggered in Swift")
        Permissions.contactPermission { granted in
            switch granted {
            case true:
                call.resolve([
                    "granted": true
                ])
            default:
                call.resolve([
                    "granted": false
                ])
            }
        }
    }

    @objc func getContacts(_ call: CAPPluginCall) {
        var contactsArray: [PluginCallResultData] = []
        Permissions.contactPermission { granted in
            if granted {
                do {
                    let contacts = try Contacts.getContactFromCNContact()

                    for contact in contacts {
                        var phoneNumbers: [PluginCallResultData] = []
                        var emails: [PluginCallResultData] = []
                        for number in contact.phoneNumbers {
                            let numberToAppend = number.value.stringValue
                            let label = number.label ?? ""
                            let labelToAppend = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: label)
                            phoneNumbers.append([
                                "label": labelToAppend,
                                "number": numberToAppend
                            ])
                        }
                        for email in contact.emailAddresses {
                            let emailToAppend = email.value as String
                            let label = email.label ?? ""
                            let labelToAppend = CNLabeledValue<NSString>.localizedString(forLabel: label)
                            emails.append([
                                "label": labelToAppend,
                                "address": emailToAppend
                            ])
                        }

                        var contactResult: PluginCallResultData = [
                            "contactId": contact.identifier,
                            "displayName": "\(contact.givenName) \(contact.familyName)",
                            "phoneNumbers": phoneNumbers,
                            "emails": emails
                        ]
                        if let photoThumbnail = contact.thumbnailImageData {
                            contactResult["photoThumbnail"] = "data:image/png;base64,\(photoThumbnail.base64EncodedString())"
                            if let birthday = contact.birthday?.date {
                                contactResult["birthday"] = self.birthdayFormatter.string(from: birthday)
                            }
                            if !contact.organizationName.isEmpty {
                                contactResult["organizationName"] = contact.organizationName
                                contactResult["organizationRole"] = contact.jobTitle
                            }
                        }
                        contactsArray.append(contactResult)
                    }

                    call.resolve([
                        "contacts": contactsArray
                    ])
                } catch let error as NSError {
                    call.reject(error.localizedDescription, nil, error)
                }
            } else {
                call.reject("User denied access to contacts")
            }
        }
    }

    /**
     * [WIP]
     *
     * Find a contact by name or fallback to return all contacts if no search string is given.
     */
    @objc func findContacts(_ call: CAPPluginCall) {
        Permissions.contactPermission { granted in
            if !granted {
                call.reject("User denied access to contacts")
                return
            }
        }

        let searchString = call.getString("searchString", "")
        if searchString == "" {
            return getContacts(call)
        }

        do {
            let contacts = try Contacts.findContacts(withName: searchString)

            call.resolve([
                "contacts": contacts
            ])
        } catch let error as NSError {
            call.reject(error.localizedDescription, nil, error)
        }
    }

    @objc func saveContact(_ call: CAPPluginCall) {
        Permissions.contactPermission { granted in
            if !granted {
                call.reject("User denied access to contacts")
                return
            }
        }


        let identifier = call.getString("identifier", "")
        var isNew = true
        var foundContact: CNContact?

        var contact = CNMutableContact()

        if(!identifier.isEmpty){
            do {
                try foundContact = Contacts.findContactById(withIdentifier: identifier)

                if(foundContact != nil) {
                    isNew = false
                    contact = foundContact!.mutableCopy() as! CNMutableContact
                }
            } catch let error as NSError {
                print("find contact error")
                print(error)
            }
        }

        let saveMechanism = call.getString("saveMechanism", "")

        contact.contactType = CNContactType(rawValue: call.getInt("contactType", 0))!

        // Name information
        let namePrefix = call.getString("namePrefix", "")
        if namePrefix != "namePrefix" {
            contact.namePrefix = namePrefix
        }
        let givenName = call.getString("givenName", "")
        if givenName != "givenName" {
            contact.givenName = givenName
        }
        let middleName = call.getString("middleName", "")
        if middleName != "middleName" {
            contact.middleName = middleName
        }
        let familyName = call.getString("familyName", "")
        if familyName != "familyName" {
            contact.familyName = familyName
        }
        let nameSuffix = call.getString("nameSuffix", "")
        if nameSuffix != "nameSuffix" {
            contact.nameSuffix = nameSuffix
        }

        if saveMechanism == "name" {

            // --- Save
            print("save contact")

            if(isNew) {

                print("create contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    try CNContactStore().execute(saveRequest)
                    print("created contact")
                    call.resolve(["result": "created"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }

            } else {

                print("update contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(contact)
                    try CNContactStore().execute(saveRequest)
                    print("updated contact")
                    call.resolve(["result": "updated"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }
            }

            return
        }

        // Work information
        let jobTitle = call.getString("jobTitle", "")
        if jobTitle != "" {
            contact.jobTitle = jobTitle
        }
        let organizationName = call.getString("organizationName", "")
        if organizationName != "" {
            contact.organizationName = organizationName
        }

        if saveMechanism == "name-company" {

            // --- Save
            print("save contact")

            if(isNew) {

                print("create contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    try CNContactStore().execute(saveRequest)
                    print("created contact")
                    call.resolve(["result": "created"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }

            } else {

                print("update contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(contact)
                    try CNContactStore().execute(saveRequest)
                    print("updated contact")
                    call.resolve(["result": "updated"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }
            }

            return
        }

        // Email Addresses
        let emailAddresses = foundContact?.emailAddresses
        for givenContactAddress in call.getArray("emailAddresses", JSObject.self) ?? [] {
            if let address = givenContactAddress["address"] as? NSString {
                let isDuplicate = emailAddresses?.contains { $0.value as NSString == address } ?? false
                if !isDuplicate && address != "" {
                    contact.emailAddresses.append(CNLabeledValue(
                        label: givenContactAddress["label"] as? String,
                        value: address
                    ))
                }
            }
        }

        // Phone Numbers
        let phoneNumbers = foundContact?.phoneNumbers
        for givenContactPhoneNumber in call.getArray("phoneNumbers", JSObject.self) ?? [] {
            if let number = givenContactPhoneNumber["number"] as? NSString {
                let isDuplicate = phoneNumbers?.contains { $0.value.stringValue as NSString == number } ?? false
                if !isDuplicate {
                    contact.phoneNumbers.append(CNLabeledValue(
                        label: givenContactPhoneNumber["label"] as? String,
                        value: CNPhoneNumber(stringValue: number as String)
                    ))
                }
            }
        }

        // URL Addresses
        let urlAddresses = foundContact?.urlAddresses
        for givenContactURLAddress in call.getArray("urlAddresses", JSObject.self) ?? [] {
            if let url = givenContactURLAddress["url"] as? NSString {
                let isDuplicate = urlAddresses?.contains { $0.value as NSString == url } ?? false
                if !isDuplicate && url != "" {
                    contact.urlAddresses.append(CNLabeledValue(
                        label: givenContactURLAddress["label"] as? String,
                        value: url
                    ))
                }
            }
        }

        if saveMechanism == "name-company-contact" {

            // --- Save
            print("save contact")

            if(isNew) {

                print("create contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    try CNContactStore().execute(saveRequest)
                    print("created contact")
                    call.resolve(["result": "created"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }

            } else {

                print("update contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(contact)
                    try CNContactStore().execute(saveRequest)
                    print("updated contact")
                    call.resolve(["result": "updated"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }
            }

            return
        }

        // POSTAL Addresses
        let postalAddresses = foundContact?.postalAddresses
        for givenContactPostalAddress in call.getArray("postalAddresses", JSObject.self) ?? [] {
            if let address = givenContactPostalAddress["address"] as? JSObject {
                let isDuplicate = postalAddresses?.contains { existingAddress in
                    let existingAddressValue = existingAddress.value as CNPostalAddress
                    return address["street"] as? String == existingAddressValue.street &&
                           address["state"] as? String == existingAddressValue.state &&
                           address["city"] as? String == existingAddressValue.city &&
                           address["country"] as? String == existingAddressValue.country &&
                           address["postalCode"] as? String == existingAddressValue.postalCode
                } ?? false

                if !isDuplicate {
                    contact.postalAddresses.append(CNLabeledValue(
                        label: givenContactPostalAddress["label"] as? String,
                        value: Contacts.getPostalAddressFromAddress(jsAddress: address)
                    ))
                }
            }
        }

        if saveMechanism == "name-company-contact-address" {

            // --- Save
            print("save contact")

            if(isNew) {

                print("create contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    try CNContactStore().execute(saveRequest)
                    print("created contact")
                    call.resolve(["result": "created"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }

            } else {

                print("update contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(contact)
                    try CNContactStore().execute(saveRequest)
                    print("updated contact")
                    call.resolve(["result": "updated"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }
            }

            return
        }

        // NOTES
        // contact.note = call.getString("note", "")

        // BIRTHDAY
        // if let birthday = self.birthdayFormatter.date(from: call.getString("birthday", "")) {
        //     contact.birthday = Calendar.current.dateComponents([.day, .month, .year], from: birthday)
        // }

        // SOCIAL PROFILES
        let socialProfiles = foundContact?.socialProfiles
        for givenContactSocialProfile in call.getArray("socialProfiles", JSObject.self) ?? [] {
            if let profile = givenContactSocialProfile["profile"] as? JSObject {
                let isDuplicate = socialProfiles?.contains { existingProfile in
                    let existingProfileValue = existingProfile.value as CNSocialProfile
                    return profile["username"] as? String == existingProfileValue.username &&
                           profile["urlString"] as? String == existingProfileValue.urlString &&
                           profile["service"] as? String == existingProfileValue.service
                } ?? false

                if !isDuplicate {
                    contact.socialProfiles.append(CNLabeledValue(
                        label: givenContactSocialProfile["label"] as? String,
                        value: CNSocialProfile(
                            urlString: profile["urlString"] as? String,
                            username: profile["username"] as? String,
                            userIdentifier: "",
                            service: profile["service"] as? String
                        )
                    ))
                }
            }
        }

        if saveMechanism == "name-company-contact-address-social" {

            // --- Save
            print("save contact")

            if(isNew) {

                print("create contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.add(contact, toContainerWithIdentifier: nil)
                    try CNContactStore().execute(saveRequest)
                    print("created contact")
                    call.resolve(["result": "created"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }

            } else {

                print("update contact")

                do {
                    let saveRequest = CNSaveRequest()
                    saveRequest.update(contact)
                    try CNContactStore().execute(saveRequest)
                    print("updated contact")
                    call.resolve(["result": "updated"])
                    print("call resolved")
                } catch let error as NSError {
                    print(error)
                    call.reject(error.localizedDescription, nil, error)
                    print("call rejected")
                }
            }

            return
        }

        // Image
        let image = call.getString("image", "")
        if image != "" {
            if let imageUrl = URL(string: image) {
                do {
                    // Attempt to load image data from the URL
                    let imageData = try Data(contentsOf: imageUrl)
                    contact.imageData = imageData
                } catch {
                    // Handle the error if the image data loading fails
                    print("Error loading image data: \(error)")
                    // You might want to handle the error in a way that makes sense for your app
                    call.reject("Error loading image data: \(error)")
                }
            } else {
                // Handle the case where the image URL is invalid
                print("Invalid image URL")
                // You might want to handle this case in a way that makes sense for your app
                call.reject("Invalid image URL")
            }
        }

        // --- Save
        print("save contact")

        if(isNew) {

            print("create contact")

            do {
                let saveRequest = CNSaveRequest()
                saveRequest.add(contact, toContainerWithIdentifier: nil)
                try CNContactStore().execute(saveRequest)
                print("created contact")
                call.resolve(["result": "created"])
                print("call resolved")
            } catch let error as NSError {
                print(error)
                call.reject(error.localizedDescription, nil, error)
                print("call rejected")
            }

        } else {

            print("update contact")

            do {
                let saveRequest = CNSaveRequest()
                saveRequest.update(contact)
                try CNContactStore().execute(saveRequest)
                print("updated contact")
                call.resolve(["result": "updated"])
                print("call resolved")
            } catch let error as NSError {
                print(error)
                call.reject(error.localizedDescription, nil, error)
                print("call rejected")
            }
        }
    }
}
