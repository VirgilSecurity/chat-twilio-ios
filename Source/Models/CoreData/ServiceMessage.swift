//
//  ServiceMessage+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/19/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK

@objc(ServiceMessage)
public final class ServiceMessage: NSManagedObject, Codable {
    @NSManaged public var rawMessage: Data
    @NSManaged public var channel: Channel?

    @NSManaged private var rawType: String
    @NSManaged private var rawCardsAdd: [String]
    @NSManaged private var rawCardsRemove: [String]

    private static let EntityName = "ServiceMessage"

    enum CodingKeys: String, CodingKey {
        case rawMessage
        case rawType
        case rawCardsAdd
        case rawCardsRemove
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawMessage, forKey: .rawMessage)
        try container.encode(self.rawType, forKey: .rawType)
        try container.encode(self.rawCardsAdd, forKey: .rawCardsAdd)
        try container.encode(self.rawCardsRemove, forKey: .rawCardsRemove)
    }

    public var message: RatchetGroupMessage {
        get {
            return try! RatchetGroupMessage.deserialize(input: self.rawMessage)
        }

        set {
            self.rawMessage = newValue.serialize()
        }
    }

    public var type: ServiceMessageType {
        get {
            return ServiceMessageType(rawValue: self.rawType) ?? .newSession
        }

        set {
            self.rawType = newValue.rawValue
        }
    }

    public var cardsAdd: [Card] {
        get {
            let cards: [Card] = self.rawCardsAdd.map {
                try! VirgilHelper.shared.importCard(fromBase64Encoded: $0)
            }

            return cards
        }

        set {
            self.rawCardsAdd = newValue.map { try! $0.getRawCard().exportAsBase64EncodedString() }
        }
    }

    public var cardsRemove: [Card] {
        get {
            let cards: [Card] = self.rawCardsRemove.map {
                try! VirgilHelper.shared.importCard(fromBase64Encoded: $0)
            }

            return cards
        }

        set {
            self.rawCardsRemove = newValue.map { try! $0.getRawCard().exportAsBase64EncodedString() }
        }
    }

    convenience init(message: RatchetGroupMessage,
                     type: ServiceMessageType,
                     add: [Card] = [],
                     remove: [Card] = [],
                     managedContext: NSManagedObjectContext = CoreDataHelper.shared.managedContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.message = message
        self.type = type
        self.cardsAdd = add
        self.cardsRemove = remove
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let managedContext = CoreDataHelper.shared.managedContext

        guard let entity = NSEntityDescription.entity(forEntityName: ServiceMessage.EntityName,
                                                      in: managedContext) else {
                                                        throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.rawMessage = try container.decode(Data.self, forKey: .rawMessage)
        self.rawType = try container.decode(String.self, forKey: .rawType)
        self.rawCardsAdd = try container.decodeIfPresent([String].self, forKey: .rawCardsAdd) ?? []
        self.rawCardsRemove = try container.decodeIfPresent([String].self, forKey: .rawCardsRemove) ?? []
    }
}

extension ServiceMessage {
    static func `import`(_ base64EncodedString: String) throws -> ServiceMessage {
        guard let data = Data(base64Encoded: base64EncodedString) else {
            throw NSError()
        }

        return try JSONDecoder().decode(ServiceMessage.self, from: data)
    }

    func export() throws -> String {
        return try JSONEncoder().encode(self).base64EncodedString()
    }
}
