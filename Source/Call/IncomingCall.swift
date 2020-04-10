//
//  IncomingCall.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 09.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC

public class IncomingCall: Call {

    private let sessionDescription: RTCSessionDescription

    public init(from: NetworkMessage.CallOffer, to: String, signalingTo signalingDelegate: CallSignalingDelegate? = nil) {
        self.sessionDescription = from.rtcSessionDescription

        super.init(withId: from.callUUID, caller: from.caller, callee: to, signalingTo: signalingDelegate)
    }

    override var isOutgoing: Bool {
        return false
    }

    override var opponent: String {
        return self.caller
    }

    public func start() {
        self.state = .new

        self.setupPeerConnection()

        guard let peerConnection = self.peerConnection else {
            return
        }

        self.state = .ringing

        peerConnection.setRemoteDescription(self.sessionDescription) { error in
            guard let error = error else {
                return
            }

            Log.error(error, message: "Failed to set an offer session description as remote session description")

            self.didFail(CallError.configurationFailed)
        }
    }

    public func answer() {
        guard let peerConnection = self.peerConnection else {
            return
        }

        self.state = .accepted

        let constrains = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)

        peerConnection.answer(for: constrains) { sdp, error in
            guard let sdp = sdp else {
                if let error = error {
                    Log.error(error, message: "Failed to create an answer session description")
                }

                self.didFail(CallError.configurationFailed)

                return
            }

            peerConnection.setLocalDescription(sdp) { error in
                guard let error = error else {
                    let callAnswer = NetworkMessage.CallAnswer(callUUID: self.uuid, sdp: sdp.sdp)

                    self.didCreateAnswer(callAnswer)

                    return
                }

                Log.error(error, message: "Failed to set an answer session description as local session description")

                self.didFail(CallError.configurationFailed)
            }
        }
    }

}
