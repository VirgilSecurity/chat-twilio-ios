//
//  MessageType.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

public enum MessageType: String {
    case text
    case photo
    case audio

    init?(_ type: TwilioHelper.MediaType) {
        switch type {
        case .photo:
            self = .photo
        case .audio:
            self = .audio
        }
    }
}
