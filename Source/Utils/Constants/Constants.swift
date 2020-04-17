//
//  Constants.swift
//  VirgilSigner iOS
//
//  Created by Oleksandr Deundiak on 9/25/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit
import XMPPFrameworkSwift

enum Constants {
    enum EnvPrefix: String {
        case dev = "-dev"
        case stg = "-stg"
        case prod = ""
    }

    static let KeychainGroup: String = "com.virgil.VirgilMessenger\(Constants.envPrefix.rawValue.replacingOccurrences(of: "-", with: "."))"
    static let appGroup: String = "group.virgil.notification\(Constants.envPrefix.rawValue)"
    static let pushesNode: String = "node"

#if DEBUG
    static let pushMode: String = "dev"
#else
    static let pushMode: String = "prod"
#endif
}

enum URLConstants {
    // Ejabberd
    static let ejabberdHost: String = "xmpp\(Constants.envPrefix.rawValue).virgilsecurity.com"
    static let ejabberdHostPort: UInt16 = 5222
    static let ejabberdPushHost: String = "push-notifications-proxy"

    // Backend
    static let serviceBaseURL: String = "https://messenger\(Constants.envPrefix.rawValue).virgilsecurity.com"

    static let virgilJwtEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/virgil-jwt/")!
    static let ejabberdJwtEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/ejabberd-jwt/")!
    static let signUpEndpoint = URL(string: "\(URLConstants.serviceBaseURL)/signup/")!

    // Other links
    static let termsAndConditionsURL = "https://virgilsecurity.com/terms-of-service"
    static let privacyURL = "https://virgilsecurity.com/privacy-policy"
}

enum ChatConstants {
    static let limitLength = 32
    static let characterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-()/='+:?!%&*<>;{}@#_")
    static let chatMaxCharectersCount: UInt = 1000
    static let chatPageSize = 20
}

enum UIConstants {
    static let TransitionAnimationDuration: TimeInterval = 0.3

    static var colorPairs: [ColorPair] = [ColorPair(UIColor(rgb: 0x009DFF), UIColor(rgb: 0x6AC7FF)),
                                          ColorPair(UIColor(rgb: 0x541C12), UIColor(rgb: 0x9E3621)),
                                          ColorPair(UIColor(rgb: 0x156363), UIColor(rgb: 0x21999E)),
                                          ColorPair(UIColor(rgb: 0x54CB68), UIColor(rgb: 0x9ADD7D)),          // light green
                                          ColorPair(UIColor(rgb: 0x665FFF), UIColor(rgb: 0x81ADFF)),          // strange
                                          ColorPair(UIColor(rgb: 0xFFA95C), UIColor(rgb: 0xFFCB66))]          // orange-yellow
}
