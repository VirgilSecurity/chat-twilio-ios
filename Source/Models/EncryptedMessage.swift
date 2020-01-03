//
//  EncryptedMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import XMPPFrameworkSwift

public class EncryptedMessage: Codable {
    let ciphertext: String
    let date: Date

    static func `import`(_ message: XMPPMessage) throws -> EncryptedMessage {
        let body = try message.getBody()

        guard let data = Data(base64Encoded: body) else {
            throw Twilio.Error.invalidMessage
        }

        return try JSONDecoder().decode(EncryptedMessage.self, from: data)
    }

    func export() throws -> String {
        let data = try JSONEncoder().encode(self)

        return data.base64EncodedString()
    }
}
