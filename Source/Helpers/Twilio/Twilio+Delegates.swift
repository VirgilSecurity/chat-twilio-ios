//
//  Twilio+Delegates.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import TwilioChatClient

extension Twilio {
    public enum ConnectionState: String {
        case unknown = "unknown"
        case disconnected = "disconnected"
        case connected = "connected"
        case connecting = "connecting"
        case denied = "denied"
        case error = "error"

        init(state: TCHClientConnectionState) {
            switch state {
            case .unknown: self = .unknown
            case .disconnected: self = .disconnected
            case .connected: self = .connected
            case .connecting: self = .connecting
            case .denied: self = .denied
            case .error: self = .error
            @unknown default:
                self = .unknown
            }
        }
    }
}

extension Twilio: TwilioChatClientDelegate {
    public func chatClient(_ client: TwilioChatClient, connectionStateUpdated state: TCHClientConnectionState) {
        let connectionState = ConnectionState(state: state)

        let stateStr = connectionState.rawValue
        Log.debug("\(stateStr)")

        Notifications.post(connectionState: connectionState)
    }

    public func chatClient(_ client: TwilioChatClient, channelAdded channel: TCHChannel) {
        self.queue.async {
            do {
                if channel.status != .joined {
                    try channel.join().startSync().getResult()

                    let attributes = try channel.getAttributes()

                    guard attributes.initiator != self.identity else {
                        return
                    }
                    
                    try ChatsManager.join(channel)

                    try ChatsManager.update(twilioChannel: channel).startSync().getResult()

                    Notifications.post(.channelAdded)
                }
            } catch {
                Log.error("\(error)")
            }
        }
    }

    public func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        guard message.author != self.identity, channel.status == .joined else {
            return
        }

        self.queue.async {
            do {
                guard let message = try MessageProcessor.process(message: message, from: channel) else {
                    return Notifications.post(.messageAdded)
                }

                if let currentChannel = self.currentChannel, try channel.getSid() == currentChannel.getSid() {
                    Notifications.post(message: message)
                } else {
                    Notifications.post(.messageAdded)
                }
            } catch {
                Log.error("\(error)")
            }
        }
    }

    public func chatClientTokenWillExpire(_ client: TwilioChatClient) {
        do {
            let token = try Virgil.shared.client.getTwilioToken(identity: self.identity)

            self.client.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }
    }

    public func chatClientTokenExpired(_ client: TwilioChatClient) {
        do {
            let token = try Virgil.shared.client.getTwilioToken(identity: self.identity)

            self.client.updateToken(token)
        } catch {
            Log.error("Update Twilio Token failed: \(error.localizedDescription)")
        }
    }
}
