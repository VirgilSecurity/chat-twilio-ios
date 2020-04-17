//
//  ChatsManager+Update.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilE3Kit

extension ChatsManager {
    private static let queue = DispatchQueue(label: "ChatsManager")

    public static func updateChannels() -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            self.queue.async {
                do {
                    if let error = operation.findDependencyError() {
                        throw error
                    }

                    let twilioChannels = Twilio.shared.channels.subscribedChannels()

                    let coreGroupChannels = Storage.shared.getGroupChannels()

                    for coreChannel in coreGroupChannels {
                        if (try? Twilio.shared.getChannel(coreChannel)) == nil {
                            try Virgil.ethree.deleteGroup(id: coreChannel.sid).startSync().get()
                            try Storage.shared.delete(channel: coreChannel)
                        }
                    }

                    guard !twilioChannels.isEmpty else {
                        completion((), nil)
                        return
                    }

                    var singleChannelOperations: [CallbackOperation<Void>] = []
                    var groupChannelOperations: [CallbackOperation<Void>] = []

                    for twilioChannel in twilioChannels {
                        let operation = self.update(twilioChannel: twilioChannel)

                        let attributes = try twilioChannel.getAttributes()

                        switch attributes.type {
                        case .single:
                            singleChannelOperations.append(operation)
                        case .group:
                            groupChannelOperations.append(operation)
                        }
                    }

                    for singleOperation in singleChannelOperations {
                        for groupOperation in groupChannelOperations {
                            groupOperation.addDependency(singleOperation)
                        }
                    }

                    let operations = singleChannelOperations + groupChannelOperations

                    let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                    operations.forEach {
                        completionOperation.addDependency($0)
                    }

                    let queue = OperationQueue()
                    queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
                }
                catch {
                    completion(nil, error)
                }
            }
        }
    }

    public static func update(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                Log.debug("Updating channel: \(String(describing: twilioChannel))")
                let attributes = try twilioChannel.getAttributes()

                // Update Storage
                let coreChannel = try self.updatePersistentStorage(with: twilioChannel)

                if attributes.type == .group {
                    // Update Virgil Group
                    let group = try self.updateVirgilGroup(with: coreChannel,
                                                           initiator: attributes.initiator)
                    coreChannel.set(group: group)
                }

                // Load, decrypt and save messeges
                let coreCount = coreChannel.allMessages.count
                let twilioCount = try twilioChannel.getMessagesCount().startSync().get()

                let toLoad = twilioCount - coreCount

                guard toLoad > 0 else {
                    completion((), nil)
                    return
                }

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    private static func updateVirgilGroup(with coreChannel: Storage.Channel,
                                          initiator: String) throws -> Group {
        let group: Group

        if let cachedGroup = try Virgil.ethree.getGroup(id: coreChannel.sid) {
            group = cachedGroup
        }
        else {
            do {
                group = try Virgil.ethree.loadGroup(id: coreChannel.sid, initiator: initiator)
                    .startSync()
                    .get()
            }
            catch GroupError.groupWasNotFound {
                if initiator == Virgil.ethree.identity {
                    var result = FindUsersResult()
                    coreChannel.cards.forEach {
                        result[$0.identity] = $0
                    }

                    group = try Virgil.ethree.createGroup(id: coreChannel.sid, with: result)
                        .startSync()
                        .get()
                }
                else {
                    throw GroupError.groupWasNotFound
                }
            }
        }

        return group
    }

    private static func updatePersistentStorage(with twilioChannel: TCHChannel) throws -> Storage.Channel {
        let coreChannel: Storage.Channel
        if let channel = try? Storage.shared.getChannel(twilioChannel) {
            coreChannel = channel
        }
        else {
            let sid = try twilioChannel.getSid()
            let attributes = try twilioChannel.getAttributes()

            switch attributes.type {
            case .single:
                let name = try Twilio.shared.getCompanion(from: attributes)

                let card = try Virgil.ethree.findUser(with: name).startSync().get()

                coreChannel = try Storage.shared.createSingleChannel(sid: sid,
                                                                      initiator: attributes.initiator,
                                                                      card: card)
            case .group:
                let result = try Virgil.ethree.findUsers(with: Array(attributes.members)).startSync().get()
                let cards = Array(result.values)

                let name = try twilioChannel.getFriendlyName()

                coreChannel = try Storage.shared.createGroupChannel(name: name,
                                                                     sid: sid,
                                                                     initiator: attributes.initiator,
                                                                     cards: cards)
            }
        }

        return coreChannel
    }
}
