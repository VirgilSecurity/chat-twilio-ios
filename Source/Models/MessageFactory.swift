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

import Chatto
import ChattoAdditions

class MessageFactory {
    private class func createMessageModel(_ uid: String, isIncoming: Bool, type: String, status: MessageStatus, date: Date) -> MessageModel {
        let senderId = isIncoming ? "1" : "2"

        let messageModel = MessageModel(uid: uid,
                                        senderId: senderId,
                                        type: type,
                                        isIncoming: isIncoming,
                                        date: date,
                                        status: status)

        return messageModel
    }

    class func createTextMessageModel(_ uid: String,
                                      text: String,
                                      isIncoming: Bool,
                                      status: MessageStatus,
                                      date: Date) -> DemoTextMessageModel {
        let messageModel = createMessageModel(uid,
                                              isIncoming: isIncoming,
                                              type: TextMessageModel<MessageModel>.chatItemType,
                                              status: status,
                                              date: date)
        let textMessageModel = DemoTextMessageModel(messageModel: messageModel, text: text)

        return textMessageModel
    }

    class func createPhotoMessageModel(_ uid: String,
                                       image: UIImage,
                                       size: CGSize,
                                       isIncoming: Bool,
                                       status: MessageStatus,
                                       date: Date) -> DemoPhotoMessageModel {
        let messageModel = createMessageModel(uid,
                                              isIncoming: isIncoming,
                                              type: PhotoMessageModel<MessageModel>.chatItemType,
                                              status: status,
                                              date: date)
        let photoMessageModel = DemoPhotoMessageModel(messageModel: messageModel, imageSize: size, image: image)

        return photoMessageModel
    }

    class func createAudioMessageModel(_ uid: String,
                                       audio: Data,
                                       duration: TimeInterval,
                                       isIncoming: Bool,
                                       status: MessageStatus,
                                       date: Date) -> DemoAudioMessageModel {
        let messageModel = createMessageModel(uid,
                                              isIncoming: isIncoming,
                                              type: AudioMessageModel<MessageModel>.chatItemType,
                                              status: status,
                                              date: date)
        let audioMessageModel = DemoAudioMessageModel(messageModel: messageModel, audio: audio, duration: duration)

        return audioMessageModel
    }
}

extension TextMessageModel {
    static var chatItemType: ChatItemType {
        return "text"
    }
}

extension PhotoMessageModel {
    static var chatItemType: ChatItemType {
        return "photo"
    }
}

extension AudioMessageModel {
    static var chatItemType: ChatItemType {
        return "audio"
    }
}
