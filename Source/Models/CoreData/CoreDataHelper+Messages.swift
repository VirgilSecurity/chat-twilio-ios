//
//  CoreDataHelper+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension CoreDataHelper {
    func saveMessage(_ message: Message, to channel: Channel) throws {
        let messages = channel.mutableOrderedSetValue(forKey: Channel.MessagesKey)
        messages.add(message)

        Log.debug("Core Data: new message added")
        self.appDelegate.saveContext()
    }

    func saveTextMessage(_ body: String, to channel: Channel? = nil, isIncoming: Bool, date: Date = Date()) throws {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let message = try self.createTextMessage(body, in: channel, isIncoming: isIncoming, date: date)

        try self.saveMessage(message, to: channel)
    }

    func saveMediaMessage(_ data: Data, to channel: Channel? = nil, isIncoming: Bool, date: Date = Date(), type: MessageType) throws {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let message = try self.createMediaMessage(data, in: channel, isIncoming: isIncoming, date: date, type: type)

        try self.saveMessage(message, to: channel)
    }

    func createTextMessage(_ body: String,
                           in channel: Channel? = nil,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {
        return try Message(body: body,
                           type: .text,
                           isIncoming: isIncoming,
                           date: date,
                           managedContext: self.managedContext)
    }

    func createMediaMessage(_ data: Data,
                            in channel: Channel? = nil,
                            isIncoming: Bool,
                            date: Date = Date(),
                            type: MessageType) throws -> Message {
        return try Message(media: data,
                           type: type,
                           isIncoming: isIncoming,
                           date: date,
                           managedContext: self.managedContext)
    }
}
