//
//  MessageProcessor.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

class MessageProcessor {
    enum Error: Swift.Error {
        case missingThumbnail
        case dataToStrFailed
    }
    
    static func process(_ encryptedMessage: EncryptedMessage, from author: String) throws {
        let channel = try self.setupCoreChannel(name: author)

        let decrypted = try self.decrypt(encryptedMessage, from: channel)
        
        var decryptedAdditional: Data? = nil
        
        if let data = encryptedMessage.additionalData {
            decryptedAdditional = try Virgil.ethree.authDecrypt(data: data, from: channel.getCard())
        }
        
        let messageContent = try self.migrationSafeContentImport(from: decrypted,
                                                                 version: encryptedMessage.modelVersion)
        
        try self.process(messageContent,
                         additionalData: decryptedAdditional,
                         channel: channel,
                         author: author,
                         date: encryptedMessage.date)
    }
    
    private static func process(_ messageContent: MessageContent,
                                additionalData: Data?,
                                channel: Channel,
                                author: String,
                                date: Date) throws {
        let message: Message
    
        switch messageContent {
        case .text(let textContent):
            message = try CoreData.shared.createTextMessage(with: textContent,
                                                            in: channel,
                                                            isIncoming: true,
                                                            date: date)
            
        case .photo(let photoContent):
            guard let thumbnail = additionalData else {
                throw Error.missingThumbnail
            }
            
            message = try CoreData.shared.createPhotoMessage(with: photoContent,
                                                             thumbnail: thumbnail,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)
        case .voice(let voiceContent):
            message = try CoreData.shared.createVoiceMessage(with: voiceContent,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)
        }
        
        self.postNotification(about: message, author: author)
    }
    
    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> MessageContent {
        let messageContent: MessageContent
        
        switch version {
        case .v1:
            guard let body = String(data: data, encoding: .utf8) else {
                throw Error.dataToStrFailed
            }
            
            let textContent = TextContent(body: body)
            messageContent = MessageContent.text(textContent)
        case .v2:
            messageContent = try MessageContent.import(from: data)
        }

        return message
    }

    private static func setupCoreChannel(name: String) throws -> Storage.Channel {
        let channel: Storage.Channel

        if let coreChannel = Storage.shared.getChannel(withName: name) {
            channel = coreChannel
        } else {
            let card = try Virgil.ethree.findUser(with: name).startSync().get()

            channel = try Storage.shared.getChannel(withName: name)
                ?? Storage.shared.createSingleChannel(initiator: name, card: card)
        }

        return channel
    }
    
    private static func decrypt(_ message: EncryptedMessage, from channel: Channel) throws -> Data {
        let decrypted: Data
        
        do {
            decrypted = try Virgil.ethree.authDecrypt(data: message.ciphertext, from: channel.getCard())
        }
        catch {
            // TODO: check if needed
            try Storage.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)

            throw error
        }

        return decrypted
    }
    
    private static func postNotification(about message: Message, author: String) {
        guard let channel = CoreData.shared.currentChannel,
            channel.name == author else {
                return Notifications.post(.chatListUpdated)
        }
    
        Notifications.post(message: message)
    }
    
    private static func setupChannel(name: String) throws -> Channel {
        let channel: Channel

        if let coreChannel = CoreData.shared.getChannel(withName: name) {
            channel = coreChannel
        }
        else {
            let card = try Virgil.ethree.findUser(with: name)
                .startSync()
                .get()

            channel = try CoreData.shared.getChannel(withName: name)
                ?? CoreData.shared.createSingleChannel(initiator: name, card: card)
        }
        
        return channel
    }

    /// FIXME: From develop-voice
    static func process(_ encryptedMessage: EncryptedMessage, from author: String) throws {
        let channel = try self.setupCoreChannel(name: author)

        let decrypted = try self.decrypt(encryptedMessage, from: channel)

        let message = try self.migrationSafeContentImport(from: decrypted,
                                                                 version: encryptedMessage.version)

        try self.process(message, channel: channel, date: encryptedMessage.date)
    }

    private static func process(_ message: Message, channel: Storage.Channel, date: Date) throws {
        switch message {
        case .text(let content):
            let message = try Storage.shared.createTextMessage(content.body,
                                                                in: channel,
                                                                isIncoming: true,
                                                                date: date)

            self.postNotification(about: message)

        case .callOffer:
            Notifications.post(message: message)

            let message = try Storage.shared.createCallMessage(in: channel,
                                                                isIncoming: true,
                                                                date: date)

            self.postNotification(about: message)

        case .callAnswer, .iceCandidate:
            //  FIXME: Unify the handling approach for '.text' as well.
            Notifications.post(message: message)
        }
    }

    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> Message {
        let message: Message

        switch version {
        case .v1:
            let string = String(data: data, encoding: .utf8)!
            let textContent = Message.Text(body: string)
            message = Message.text(textContent)
        case .v2:
            message = try Message.import(from: data)
        }

        return message
    }

    private static func setupCoreChannel(name: String) throws -> Storage.Channel {
        let channel: Storage.Channel

        if let coreChannel = Storage.shared.getChannel(withName: name) {
            channel = coreChannel
        } else {
            let card = try Virgil.ethree.findUser(with: name).startSync().get()

            channel = try Storage.shared.getChannel(withName: name)
                ?? Storage.shared.createSingleChannel(initiator: name, card: card)
        }

        return channel
    }

    private static func decrypt(_ message: EncryptedMessage, from channel: Storage.Channel) throws -> Data {
        let decrypted: Data

        do {
            decrypted = try Virgil.ethree.authDecrypt(data: message.ciphertext, from: channel.getCard())
        } catch {
            // TODO: check if needed
            try Storage.shared.createEncryptedMessage(in: channel, isIncoming: true, date: message.date)

            throw error
        }

        return decrypted
    }

    private static func postNotification(about message: Storage.Message) {
        guard Storage.shared.currentChannel != nil else {
            return Notifications.post(.chatListUpdated)
        }

        Notifications.post(message: message)
    }
}
