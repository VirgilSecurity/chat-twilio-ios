//
//  MessageProcessor.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilE3Kit

class MessageProcessor {
    enum Error: Swift.Error {
        case missingThumbnail
        case dataToStrFailed
    }

    static func process(_ encryptedMessage: EncryptedMessage, from author: String) throws {
        let channel = try self.setupChannel(name: author)

        let decrypted = try Virgil.decrypt(encryptedMessage, from: channel)

        let message = try self.migrationSafeContentImport(from: decrypted,
                                                                 version: encryptedMessage.modelVersion)

        var decryptedAdditional: Data?

        if let data = encryptedMessage.additionalData {
            decryptedAdditional = try Virgil.decrypt(data, from: channel)
        }

        try self.process(message,
                         additionalData: decryptedAdditional,
                         channel: channel,
                         author: author,
                         date: encryptedMessage.date)
    }

    private static func process(_ message: NetworkMessage,
                                additionalData: Data?,
                                channel: Storage.Channel,
                                author: String,
                                date: Date) throws {

        var unread: Bool = true
        if let channel = Storage.shared.currentChannel, channel.name == author {
            unread = false
        }

        var storageMessage: Storage.Message?

        switch message {
        case .text(let text):
            storageMessage = try Storage.shared.createTextMessage(text,
                                                                  unread: unread,
                                                                  in: channel,
                                                                  isIncoming: true,
                                                                  date: date)

        case .photo(let photo):
            guard let thumbnail = additionalData else {
                throw Error.missingThumbnail
            }

            storageMessage = try Storage.shared.createPhotoMessage(photo,
                                                             thumbnail: thumbnail,
                                                             unread: unread,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)
        case .voice(let voice):
            storageMessage = try Storage.shared.createVoiceMessage(voice,
                                                             unread: unread,
                                                             in: channel,
                                                             isIncoming: true,
                                                             date: date)

        case .callOffer:
            Notifications.post(message: message)

            storageMessage = try Storage.shared.createCallMessage(in: channel,
                                                                isIncoming: true,
                                                                date: date)
        case .newChannel(let newChannel):
            try Virgil.resolveChannel(channel, with: newChannel)

            Notifications.post(.chatListUpdated)

        case .callAcceptedAnswer, .callRejectedAnswer, .iceCandidate:
            //  TODO: Unify the handling approach for '.text' as well.
            Notifications.post(message: message)
        }

        guard let channel = Storage.shared.currentChannel,
            channel.name == author else {
                return Notifications.post(.chatListUpdated)
        }

        if let storageMessage = storageMessage {
            self.postNotification(about: storageMessage, unread: unread)
        }

        self.postLocalPushNotification(message: message, author: author)
    }

    private static func migrationSafeContentImport(from data: Data,
                                                   version: EncryptedMessageVersion) throws -> NetworkMessage {
        let message: NetworkMessage

        switch version {
        case .v1:
            guard let body = String(data: data, encoding: .utf8) else {
                throw Error.dataToStrFailed
            }

            let text = NetworkMessage.Text(body: body)
            message = NetworkMessage.text(text)
        case .v2:
            message = try NetworkMessage.import(from: data)
        }

        return message
    }

    private static func postNotification(about message: Storage.Message, unread: Bool) {
        unread ? Notifications.post(.chatListUpdated) : Notifications.post(message: message)
    }

    private static func postLocalPushNotification(message: NetworkMessage, author: String) {
        let currentChannelName = Storage.shared.currentChannel?.name
        guard currentChannelName != nil && currentChannelName != author else {
            return
        }

        PushNotifications.post(message: message, author: author)
    }

    private static func setupChannel(name: String) throws -> Storage.Channel {
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
}
