//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

public enum ChatsManager {
    public static func startSingle(with identity: String,
                                   startProgressBar: @escaping (() -> Void),
                                   completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
            do {
                let identity = identity.lowercased()

                guard identity != Twilio.shared.identity else {
                    throw UserFriendlyError.createSelfChatForbidded
                }

                guard !CoreData.shared.existsSingleChannel(with: identity) else {
                    throw UserFriendlyError.doubleChannelForbidded
                }

                startProgressBar()

                try ChatsManager.startSingle(with: identity)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public static func startSingle(with identity: String) throws {
        let card = try Virgil.ethree.findUser(with: identity).startSync().get()

        let channel = try Twilio.shared.createSingleChannel(with: identity).startSync().get()

        let sid = try channel.getSid()

        _ = try CoreData.shared.createSingleChannel(sid: sid, card: card)
    }
    
    public static func startGroup(with channels: [Channel],
                                  name: String,
                                  startProgressBar: @escaping () -> Void,
                                  completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
            do {
                let name = name.lowercased()

                guard !channels.isEmpty else {
                    throw UserFriendlyError.unknownError
                }

                startProgressBar()

                let selfIdentity = Twilio.shared.identity
                var members = channels.map { $0.name }
                members.append(selfIdentity)

                let findUsersResult = try Virgil.ethree.findUsers(with: members).startSync().get()

                let channel = try Twilio.shared.createGroupChannel(with: members, name: name)
                    .startSync()
                    .get()

                let sid = try channel.getSid()

                // FIXME: add already exists handler
                let group = try Virgil.ethree.createGroup(id: sid, with: findUsersResult).startSync().get()

                var cards = Array(findUsersResult.values)
                cards = cards.filter { $0.identity != selfIdentity }
                let coreChannel = try CoreData.shared.createGroupChannel(name: name,
                                                                         members: members,
                                                                         sid: sid,
                                                                         cards: cards)
                coreChannel.set(group: group)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
