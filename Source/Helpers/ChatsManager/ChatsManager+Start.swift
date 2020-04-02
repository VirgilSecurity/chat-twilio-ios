//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilE3Kit

public enum ChatsManager {
    public static func startSingle(with identity: String,
                                   startProgressBar: @escaping (() -> Void),
                                   completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "ChatsManager").async {
            do {
                let identity = identity.lowercased()

                guard identity != Virgil.ethree.identity else {
                    throw UserFriendlyError.createSelfChatForbidded
                }

                guard !CoreData.shared.existsSingleChannel(with: identity) else {
                    throw UserFriendlyError.doubleChannelForbidded
                }

                startProgressBar()
                
                let card = try Virgil.ethree.findUser(with: identity).startSync().get()

                try CoreData.shared.createSingleChannel(initiator: Virgil.ethree.identity, card: card)

                completion(nil)
            }
            catch FindUsersError.cardWasNotFound {
                completion(UserFriendlyError.userNotFound)
            }
            catch {
                completion(error)
            }
        }
    }
}
