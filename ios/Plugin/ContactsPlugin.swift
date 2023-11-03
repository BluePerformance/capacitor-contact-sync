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
                    var errorMessage = "Error: ";
                    errorMessage.append(error as String);

                    call.reject(errorMessage)
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
            var errorMessage = "Error: ";
            errorMessage.append(error as String);

            call.reject(errorMessage)
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

        contact.contactType = CNContactType(rawValue: call.getInt("contactType", 0))!

        // Name information

        contact.namePrefix = call.getString("namePrefix", "")
        contact.givenName = call.getString("givenName", "")
        contact.middleName = call.getString("middleName", "")
        contact.familyName = call.getString("familyName", "")
        contact.nameSuffix = call.getString("nameSuffix", "")

        // Image

        let image = call.getString("image", "")
        if(image != "") {
            let url = URL(string: image)
            contact.imageData = try? Data(contentsOf: url!)
        }

        // Work information

        contact.jobTitle = call.getString("jobTitle", "")
        contact.organizationName = call.getString("organizationName", "")

        // Email Addresses
        let emails = foundContact?.emailAddresses
        for givenContactAddress in call.getArray("emailAddresses", JSObject.self) ?? [] {
            var shouldAdd = true
            if let address = givenContactAddress["address"] as? NSString {
                for email in emails ?? [] {
                    let foundContactAddress = email.value
                    if address == foundContactAddress {
                        shouldAdd = false
                    }
                }
                if shouldAdd {
                    contact.emailAddresses.append(CNLabeledValue(
                        label: givenContactAddress["label"] as? String,
                        value: address
                    ))
                }
            }
        }

        // URL Addresses
        let urlAddresses = foundContact?.urlAddresses
        for givenContactURLAddress in call.getArray("urlAddresses", JSObject.self) ?? [] {
            var shouldAdd = true
            if let url = givenContactURLAddress["url"] as? NSString {
                for urlAddress in urlAddresses ?? [] {
                    let foundContactURLAddress = urlAddress.value
                    if url == foundContactURLAddress {
                        shouldAdd = false
                    }
                }
                if shouldAdd {
                    contact.urlAddresses.append(CNLabeledValue(
                        label: givenContactURLAddress["label"] as? String,
                        value: url
                    ))
                }
            }
        }

        // POSTAL Addresses
        let postalAddresses = foundContact?.postalAddresses
        for givenContactPostalAddress in call.getArray("postalAddresses", JSObject.self) ?? [] {
            var shouldAdd = true
            if let address = givenContactPostalAddress["address"] as? JSObject {
                for postalAddress in postalAddresses ?? [] {
                    let foundContactPostalAddress = postalAddress.value
                    let address_street = address["street"] as? String ?? ""
                    let address_state = address["state"] as? String ?? ""
                    let address_city = address["city"] as? String ?? ""
                    let address_country = address["country"] as? String ?? ""
                    let address_postalCode = address["postalCode"] as? String ?? ""

                    if
                        address_street == (foundContactPostalAddress.street)
                            && address_state == (foundContactPostalAddress.state)
                            && address_city == (foundContactPostalAddress.city)
                            && address_country == (foundContactPostalAddress.country)
                            && address_postalCode == (foundContactPostalAddress.postalCode)
                    {
                        shouldAdd = false
                    }
                }
                print("adding address")
                if shouldAdd {
                    contact.postalAddresses.append(CNLabeledValue(
                        label: givenContactPostalAddress["label"] as? String,
                        value: Contacts.getPostalAddressFromAddress(jsAddress: address)
                    ))
                }
            }
        }

        // Other
        // Phone Numbers
        let phoneNumbers = foundContact?.phoneNumbers
        for givenContactPhoneNumber in call.getArray("phoneNumbers", JSObject.self) ?? [] {
            var shouldAdd = true
            if let number = givenContactPhoneNumber["number"] as? NSString {
                for phoneNumber in phoneNumbers ?? [] {
                    let foundContactPhoneNumber = phoneNumber.value as CNPhoneNumber
                    if number == foundContactPhoneNumber.stringValue as NSString {
                        shouldAdd = false
                    }
                }
                if shouldAdd {
                    contact.phoneNumbers.append(CNLabeledValue(
                        label: givenContactPhoneNumber["label"] as? String,
                        value: CNPhoneNumber(stringValue: number as String)
                    ))
                }
            }
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
            var shouldAdd = true
            if let profile = givenContactSocialProfile["profile"] as? JSObject {
                for socialProfile in socialProfiles ?? [] {
                    let foundContactSocialProfile = socialProfile.value
                    let profile_username = profile["username"] as? String ?? ""
                    let profile_urlString = profile["urlString"] as? String ?? ""
                    let profile_service = profile["service"] as? String ?? ""

                    if
                            profile_username == (foundContactSocialProfile.username)
                            && profile_urlString == (foundContactSocialProfile.urlString)
                            && profile_service == (foundContactSocialProfile.service)
                    {
                        shouldAdd = false
                    }
                }
                print("adding profile")
                if shouldAdd {
                    contact.socialProfiles.append(CNLabeledValue(
                        label: givenContactSocialProfile["label"] as? String,
                        value:  CNSocialProfile(
                                   urlString: profile["urlString"] as? String,
                                   username: profile["username"] as? String,
                                   userIdentifier: "", // TODO: what is this?
                                   service: profile["service"] as? String
                               )
                    ))
                }
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
                var errorMessage = "Error: ";
                errorMessage.append(error as String);

                call.reject(errorMessage)
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
                var errorMessage = "Error: ";
                errorMessage.append(error as String);

                call.reject(errorMessage)
                print("call rejected")
            }
        }
    }
}
