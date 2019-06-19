import Chatto
import ChattoAdditions
import TwilioChatClient
import VirgilSDK

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")

    public static func sendServiceMessage(_ message: ServiceMessage, to coreChannel: Channel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                guard let twilioChannel = TwilioHelper.shared.getChannel(coreChannel) else {
                    throw TwilioHelperError.nilCurrentChannel
                }

                let plaintext = try message.export()

                guard let messages = twilioChannel.messages else {
                    throw TwilioHelperError.invalidChannel
                }

                let ciphertext: String
                switch coreChannel.type {
                case .single:
                    ciphertext = try VirgilHelper.shared.encrypt(plaintext, card: coreChannel.cards.first!)
                case .group:
                    ciphertext = try VirgilHelper.shared.encryptGroup(plaintext, channel: coreChannel)
                }

                TwilioHelper.shared.send(ciphertext: ciphertext,
                                         messages: messages,
                                         type: .service,
                                         identifier: message.identifier).start(completion: completion)
            } catch {
                completion(nil, error)
            }
        }
    }

    public static func sendServiceMessage(to cards: [Card], ticket: ServiceMessage) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard !cards.isEmpty else {
                completion((), nil)
                return
            }

            var operations: [CallbackOperation<Void>] = []
            for card in cards {
                guard let channel = CoreDataHelper.shared.getSingleChannel(with: card.identity) else {
                    continue
                }

                let sendOperation = MessageSender.sendServiceMessage(ticket, to: channel)
                operations.append(sendOperation)
            }

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    public func sendChangeMembers(message: Message, identifier: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                guard let channel = TwilioHelper.shared.currentChannel else {
                    throw TwilioHelperError.nilCurrentChannel
                }

                guard let messages = channel.messages, let body = message.body else {
                    throw TwilioHelperError.invalidChannel
                }

                try TwilioHelper.shared.send(ciphertext: body,
                                             messages: messages,
                                             type: .service,
                                             identifier: identifier).startSync().getResult()

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func send(message: Message, withId id: Int) throws -> UIMessageModelProtocol {
        let cards = message.channel.cards

        guard let channel = TwilioHelper.shared.currentChannel ?? TwilioHelper.shared.getChannel(message.channel),
            let messages = channel.messages else {
                throw TwilioHelperError.invalidChannel
        }

        let uiModel = message.exportAsUIModel(withId: id, status: .sending)

        self.queue.async {
            do {
                switch message.type {
                case .text:
                    guard let plaintext = message.body else {
                        throw CoreDataHelperError.invalidMessage
                    }

                    let ciphertext: String
                    switch message.channel.type {
                    case .group:
                        ciphertext = try VirgilHelper.shared.encryptGroup(plaintext, channel: message.channel)
                    case .single:
                        ciphertext = try VirgilHelper.shared.encrypt(plaintext, card: cards.first!)
                    }

                    try TwilioHelper.shared.send(ciphertext: ciphertext,
                                                 messages: messages,
                                                 type: .regular).startSync().getResult()
                case .photo:
                    break
                case .audio:
                    break
                case .changeMembers:
                    guard let plaintext = message.body else {
                        throw CoreDataHelperError.invalidMessage
                    }

                    let ciphertext = try VirgilHelper.shared.encryptGroup(plaintext, channel: message.channel)

                    try TwilioHelper.shared.send(ciphertext: ciphertext,
                                                 messages: messages,
                                                 type: .service).startSync().getResult()
                }

                self.updateMessage(uiModel, status: .success)
            } catch {
                self.updateMessage(uiModel, status: .failed)
            }
        }

        return uiModel
    }

    private func updateMessage(_ message: UIMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
            self.notifyMessageChanged(message)
        }
    }

    private func notifyMessageChanged(_ message: UIMessageModelProtocol) {
        DispatchQueue.main.async {
            self.onMessageChanged?(message)
        }
    }
}
