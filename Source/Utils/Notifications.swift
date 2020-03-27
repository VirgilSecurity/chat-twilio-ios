//
//  Notifications.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 6/27/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

public class Notifications {
    private static let center: NotificationCenter = NotificationCenter.default

    public typealias Block = (Notification) -> Void

    public enum EmptyNotification: String {
        case initializingSucceed = "Notifications.InitializingSucceed"
        case updatingSucceed = "Notifications.UpdatingSucceed"

        case chatListUpdated = "Notifications.ChatListUpdated"
        case currentChannelDeleted = "Notifications.CurrentChannelDeleted"

        case startOugoingCall = "Notifications.StartOugoingCall"
        case startIncommingCall = "Notifications.StartIncommingCall"
        case acceptCall = "Notifications.AcceptCall"
        case rejectCall = "Notifications.RejectCall"
    }

    public enum Notifications: String {
        case connectionStateUpdated = "Notifications.ConnectionStateUpdated"
        case errored = "Notifications.Errored"
        case messageAddedToCurrentChannel = "Notifications.MessageAddedToCurrentChannel"
        case callOfferReceived = "Notifications.IncommingCall"
        case callIsAccepted = "Notifications.CallIsAccepted" // TODO: Rename to callAcceptedAnswerReceived
        case callIsRejected = "Notifications.CallIsRejected" // TODO: Rename to callRejectedAnswerReceived
        case iceCandidateReceived = "Notifications.IceCandidateReceived"
    }

    public enum NotificationKeys: String {
        case newState = "NotificationKeys.NewState"
        case message = "NotificationKeys.Message"
        case error = "NotificationKeys.Error"
    }

    public enum NotificationError: Int, Swift.Error {
        case parsingFailed = 1
    }

    private static func notification(_ notification: Notifications) -> Notification.Name {
        return Notification.Name(rawValue: notification.rawValue)
    }

    private static func notification(_ notification: EmptyNotification) -> Notification.Name {
        return Notification.Name(rawValue: notification.rawValue)
    }

    public static func parse<T>(_ notification: Notification, for key: NotificationKeys) throws -> T {
        guard let userInfo = notification.userInfo,
            let result = userInfo[key.rawValue] as? T else {
                throw NotificationError.parsingFailed
        }

        return result
    }

    // FIXME
    public static func removeObservers(_ object: Any) {
        self.center.removeObserver(object)
    }
}

extension Notifications {
    public static func post(error: Error) {
        let notification = self.notification(.errored)
        let userInfo = [NotificationKeys.error.rawValue: error]

        self.center.post(name: notification, object: self, userInfo: userInfo)
    }

    public static func post(message: Storage.Message) {
        let notification = self.notification(.messageAddedToCurrentChannel)
        let userInfo = [NotificationKeys.message.rawValue: message]

        self.center.post(name: notification, object: self, userInfo: userInfo)
    }

    public static func post(message: Message) {
        switch message {
        case .text, .photo, .voice:
            // Is handled via post(message)
            // FIXME: Merge message processing aproach
            break

        case .callOffer(let callOffer):
            let notification = self.notification(Notifications.callOfferReceived)
            let userInfo = [NotificationKeys.message.rawValue: callOffer]
            self.center.post(name: notification, object: self, userInfo: userInfo)

        case .callAcceptedAnswer(let callAcceptedAnswer):
            let notification = self.notification(Notifications.callIsAccepted)
            let userInfo = [NotificationKeys.message.rawValue: callAcceptedAnswer]
            self.center.post(name: notification, object: self, userInfo: userInfo)

        case .callRejectedAnswer(let callRejectedAnswer):
            let notification = self.notification(Notifications.callIsRejected)
            let userInfo = [NotificationKeys.message.rawValue: callRejectedAnswer]
            self.center.post(name: notification, object: self, userInfo: userInfo)

        case .iceCandidate(let iceCandidate):
            let notification = self.notification(Notifications.iceCandidateReceived)
            let userInfo = [NotificationKeys.message.rawValue: iceCandidate]
            self.center.post(name: notification, object: self, userInfo: userInfo)
        }
    }

    public static func post(_ notification: EmptyNotification) {
        let notification = self.notification(notification)

        self.center.post(name: notification, object: self)
    }
}

extension Notifications {
    public static func observe(for notification: EmptyNotification, block: @escaping Block) {
        self.observe(for: [notification], block: block)
    }

    public static func observe(for notification: Notifications, block: @escaping Block) {
        let notification = self.notification(notification)

        self.center.addObserver(forName: notification, object: nil, queue: nil, using: block)
    }

    public static func observe(for notifications: [EmptyNotification], block: @escaping Block) {
        notifications.forEach {
            let notification = self.notification($0)

            self.center.addObserver(forName: notification, object: nil, queue: nil, using: block)
        }
    }
}
