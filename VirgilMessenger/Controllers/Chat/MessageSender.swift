/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import Foundation
import Chatto
import ChattoAdditions
import TwilioChatClient
import VirgilSDKPFS

public protocol DemoMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: DemoMessageModelProtocol) -> ())?

    public func sendMessages(_ messages: [DemoMessageModelProtocol]) {
        for message in messages {
            self.sendMessage(message)
        }
    }

    public func sendMessage(_ message: DemoMessageModelProtocol) {
        guard let card = VirgilHelper.sharedInstance.channelCard else {
            Log.error("channel card not found")
            self.updateMessage(message, status: .failed)
            return
        }
        Log.debug("sending to " + card.identity)
        guard let secureChat = VirgilHelper.sharedInstance.secureChat else {
            Log.error("nil Secure Chat")
            return
        }
        guard let session = secureChat.activeSession(withParticipantWithCardId: card.identifier)
        else {
            secureChat.startNewSession(withRecipientWithCard: card) { session, error in
                guard error == nil, let session = session else {
                    let errorMessage = error == nil ? "unknown error" : error!.localizedDescription
                    Log.error("creating session failed: " + errorMessage)
                    self.updateMessage(message, status: .failed)
                    return
                }
                self.sendMessage(usingSession: session, message: message)
            }
            return
        }
        self.sendMessage(usingSession: session, message: message)
    }

    private func sendMessage(usingSession session: SecureSession, message: DemoMessageModelProtocol) {
        do {
            if let textMessage = message as? DemoTextMessageModel {
                let ciphertext = try session.encrypt(textMessage.body)

                self.messageStatus(ciphertext: ciphertext, message: textMessage)
            } else if let photoMessage = message as? DemoPhotoMessageModel {
                guard let photoData = UIImageJPEGRepresentation(photoMessage.image, 0.0) else {
                    Log.error("Converting image to JPEG failed")
                    return
                }
                let ciphertext = try session.encrypt(photoData.base64EncodedString())
                guard let cipherData = ciphertext.data(using: .utf8) else {
                    Log.error("String to Data failed")
                    return
                }

                self.messageStatus(cipherphoto: cipherData, message: photoMessage)
            } else {
                Log.error("Unknown message model")
                return
            }
        } catch {
            Log.error("Error trying to encrypt message")
            self.updateMessage(message, status: .failed)
            return
        }
    }

    private func messageStatus(ciphertext: String, message: DemoTextMessageModel) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.messageStatus(ciphertext: ciphertext, message: message)
        case .sending:
            if let messages = TwilioHelper.sharedInstance.currentChannel.messages {
                let options = TCHMessageOptions().withBody(ciphertext)
                Log.debug("sending \(ciphertext)")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        self.updateMessage(message, status: .success)

                        CoreDataHelper.sharedInstance.createTextMessage(withBody: message.body, isIncoming: false, date: message.date)
                        return
                    } else {
                        Log.error("error sending: Twilio cause")
                        self.updateMessage(message, status: .failed)
                        return
                    }
                }
            } else {
                Log.error("can't get channel messages")
            }
        }
    }

    private func messageStatus(cipherphoto: Data, message: DemoPhotoMessageModel) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.messageStatus(cipherphoto: cipherphoto, message: message)
        case .sending:
            if let messages = TwilioHelper.sharedInstance.currentChannel.messages {
                let inputStream = InputStream(data: cipherphoto)
                let options = TCHMessageOptions().withMediaStream(inputStream,
                                                                  contentType: "image/jpeg",
                                                                  defaultFilename: "image.jpg",
                                                                  onStarted: {
                                                                    print("Media upload started")
                },
                                                                  onProgress: { (bytes) in
                                                                    print("Media upload progress: \(bytes)")
                }) { (mediaSid) in
                    print("Media upload completed")
                }
                Log.debug("sending photo")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        self.updateMessage(message, status: .success)

                        //CoreDataHelper.sharedInstance.createMessage(withBody: msg.body, isIncoming: false, date: message.date)
                        return
                    } else {
                        if let error = result.error {
                            Log.error("error sending: \(error.localizedDescription) with \(error.code)")
                        } else {
                            Log.error("error sending: Twilio service error")
                        }
                        self.updateMessage(message, status: .failed)
                        return
                    }
                }
            } else {
                Log.error("can't get channel messages")
            }
        }
    }

    private func updateMessage(_ message: DemoMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
            self.notifyMessageChanged(message)
        }
    }

    private func notifyMessageChanged(_ message: DemoMessageModelProtocol) {
        DispatchQueue.main.async {
             self.onMessageChanged?(message)
        }
    }
}