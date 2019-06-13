//
//  ChatsManager+Join.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

extension ChatsManager {
    public static func join(_ channel: TCHChannel) throws {
        let attributes = try TwilioHelper.shared.getAttributes(of: channel)

        switch attributes.type {
        case .single:
            guard let sid = channel.sid else {
                throw TwilioHelperError.invalidChannel
            }

            let name = TwilioHelper.shared.getCompanion(from: attributes)

            let cards = try VirgilHelper.shared.makeGetCardsOperation(identities: [name]).startSync().getResult()

            try CoreDataHelper.shared.createSingleChannel(sid: sid, card: cards.first!)

        case .group:
            let members = attributes.members.filter { !CoreDataHelper.shared.existsSingleChannel(with: $0) && $0 != TwilioHelper.shared.username }

            var cards: [Card] = []
            if !members.isEmpty {
                cards = try VirgilHelper.shared.makeGetCardsOperation(identities: members).startSync().getResult()
            }

            try? ChatsManager.startSingle(with: members, cards: cards)

            guard let sessionId = attributes.sessionId,
                let name = attributes.friendlyName,
                let sid = channel.sid else {
                    throw TwilioHelperError.invalidChannel
            }

            try CoreDataHelper.shared.createGroupChannel(name: name,
                                                         members: attributes.members,
                                                         sid: sid,
                                                         sessionId: sessionId,
                                                         additionalCards: cards)

            _ = try? VirgilHelper.shared.startNewGroupSession(identity: attributes.initiator, sessionId: sessionId)
        }
    }
}