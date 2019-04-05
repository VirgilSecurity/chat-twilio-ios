//
//  TwilioHelper+Message.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit
import TwilioChatClient
import VirgilSDK

extension TwilioHelper {
//    func setLastMessage(of messages: TCHMessages, channel: Channel, completion: @escaping () -> ()) {
//        messages.getLastWithCount(UInt(1)) { result, messages in
//            guard result.isSuccessful(),
//                let messages = messages,
//                let message = messages.last,
//                let date = message.dateUpdatedAsDate else {
//                    Log.error("get last twilio message failed with: \(result.error?.localizedDescription ?? "unknown error")")
//                    completion()
//                    return
//            }
//            channel.lastMessagesDate = date
//
//            if message.hasMedia() {
//                switch message.mediaType {
//                case MediaType.photo.rawValue:
//                    channel.lastMessagesBody = CoreDataHelper.shared.lastMessageIdentifier[CoreDataHelper.MessageType.photo.rawValue] ?? "corrupted type"
//                case MediaType.audio.rawValue:
//                    channel.lastMessagesBody = CoreDataHelper.shared.lastMessageIdentifier[CoreDataHelper.MessageType.audio.rawValue] ?? "corrupted type"
//                default:
//                    Log.error("Missing or unknown media type")
//                }
//            } else if let body = message.body {
//                if message.author != TwilioHelper.shared.username {
//                    guard let decryptedBody = VirgilHelper.shared.decrypt(body, withCard: channel.cards.first) else {
//                        completion()
//                        return
//                    }
//
//                    channel.lastMessagesBody = decryptedBody
//                }
//            } else {
//                Log.error("Empty twilio message")
//            }
//
//            completion()
//        }
//    }

    func updateMessages(count: Int, completion: @escaping (Int, Error?) -> ()) {
        guard let coreMessagesCount = CoreDataHelper.shared.currentChannel?.message?.count else {
            Log.error("Get CoreData messages count failed")
            DispatchQueue.main.async {
                completion(0, NSError())
            }
            return
        }

        let needToLoadCount = count - coreMessagesCount

        guard let messages = TwilioHelper.shared.currentChannel.messages else {
            Log.error("Twilio: nil messages in selected channel")
            DispatchQueue.main.async {
                completion(0, NSError())
            }
            return
        }

        if needToLoadCount > 0 {
            messages.getLastWithCount(UInt(needToLoadCount), completion: { result, messages in
                guard let messages = messages else {
                    Log.error("Twilio can't get last messages")
                    DispatchQueue.main.async {
                        completion(-1, NSError())
                    }
                    return
                }
                TwilioHelper.shared.queue.async {
                    for message in messages {
                        let isIncoming = message.author == TwilioHelper.shared.username ? false : true
                        guard let messageDate = message.dateUpdatedAsDate else {
                            Log.error("wrong message atributes")
                            try! CoreDataHelper.shared.saveTextMessage("Message corrupted", isIncoming: isIncoming)
                            continue
                        }
                        let makeCorruptedMessage = {
                            try! CoreDataHelper.shared.saveTextMessage("Message corrupted", isIncoming: isIncoming, date: messageDate)
                        }

                        if message.hasMedia() {
                            TwilioHelper.shared.getMediaSync(from: message) { data in
                                guard let data = data else {
                                    makeCorruptedMessage()
                                    return
                                }

                                switch message.mediaType {
                                case MediaType.photo.rawValue:
                                    try! CoreDataHelper.shared.saveMediaMessage(data, isIncoming: isIncoming, date: messageDate, type: .photo)
                                case MediaType.audio.rawValue:
                                    try! CoreDataHelper.shared.saveMediaMessage(data, isIncoming: isIncoming, date: messageDate, type: .audio)
                                default:
                                    Log.error("Missing or unknown mediaType")
                                    makeCorruptedMessage()
                                    return
                                }
                            }
                        } else if let messageBody = message.body {
                            guard let decryptedMessageBody = try? VirgilHelper.shared.decrypt(messageBody) else {
                                makeCorruptedMessage()
                                continue
                            }

                            try! CoreDataHelper.shared.saveTextMessage(decryptedMessageBody, isIncoming: isIncoming, date: messageDate)
                        } else {
                            makeCorruptedMessage()
                        }
                    }
                    DispatchQueue.main.async {
                        completion(needToLoadCount, nil)
                    }
                }
            })
        } else {
            DispatchQueue.main.async {
                completion(0, nil)
            }
        }
    }

    func makeGetMediaOperation(message: TCHMessage) -> CallbackOperation<Data> {
        return CallbackOperation<Data> { _, completion in
            let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "file.dat")
            let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

            if let outputStream = outputStream {
                message.getMediaWith(outputStream,
                                     onStarted: { Log.debug("Media upload started") },
                                     onProgress: { Log.debug("Media upload progress: \($0)") },
                                     onCompleted: { _ in Log.debug("Media upload completed") })
                { result in
                    if let error = result.error {
                        completion(nil, error)
                        return
                    }

                    let url = URL(fileURLWithPath: tempFilename)

                    guard let data = try? Data(contentsOf: url) else {
                        completion(nil, NSError())
                        return
                    }

                    completion(data, nil)
                }
            } else {
                completion(nil, NSError())
            }
        }
    }

    func getMedia(from message: TCHMessage, completion: @escaping (Data?) -> ()) {
        self.queue.async {
            let group = DispatchGroup()
            let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "file.dat")
            let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

            if let outputStream = outputStream {
                Log.debug("trying to get media")
                group.enter()
                message.getMediaWith(outputStream,
                                     onStarted: {
                                        Log.debug("Media upload started")
                },
                                     onProgress: { (bytes) in
                                        Log.debug("Media upload progress: \(bytes)")
                },
                                     onCompleted: { (mediaSid) in
                                        Log.debug("Media upload completed")
                }) { result in
                    defer { group.leave() }

                    guard result.isSuccessful() else {
                        Log.error("getting media message failed: \(result.error?.localizedDescription ?? "unknown error")")
                        completion(nil)
                        return
                    }

                    let url = URL(fileURLWithPath: tempFilename)

                    guard let data = try? Data(contentsOf: url) else {
                        Log.error("reading media from temp directory failed")
                        completion(nil)
                        return
                    }

                    completion(data)
                }
            } else {
                Log.error("outputStream failed")
            }

            group.wait()
        }
    }

    func getMediaSync(from message: TCHMessage, completion: @escaping (Data?) -> ()) {
        let group = DispatchGroup()
        let tempFilename = (NSTemporaryDirectory() as NSString).appendingPathComponent(message.mediaFilename ?? "file.dat")
        let outputStream = OutputStream(toFileAtPath: tempFilename, append: false)

        if let outputStream = outputStream {
            Log.debug("trying to get media")
            group.enter()
            message.getMediaWith(outputStream,
                                 onStarted: {
                                    Log.debug("Media upload started")
            },
                                 onProgress: { (bytes) in
                                    Log.debug("Media upload progress: \(bytes)")
            },
                                 onCompleted: { (mediaSid) in
                                    Log.debug("Media upload completed")
            }) { result in
                defer { group.leave() }

                guard result.isSuccessful() else {
                    Log.error("getting media message failed: \(result.error?.localizedDescription ?? "unknown error")")
                    completion(nil)
                    return
                }

                let url = URL(fileURLWithPath: tempFilename)

                guard let data = try? Data(contentsOf: url) else {
                    Log.error("reading media from temp directory failed")
                    completion(nil)
                    return
                }

                completion(data)
            }
        } else {
            Log.error("outputStream failed")
        }

        group.wait()
    }
}
