//
//  PhotoMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/11/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

@objc(PhotoMessage)
public class PhotoMessage: Message {
    @NSManaged public var identifier: String
    @NSManaged public var thumbnail: Data
    @NSManaged public var url: URL
    
    private static let EntityName = "PhotoMessage"
    
    convenience init(identifier: String,
                     thumbnail: Data,
                     url: URL,
                     xmppId: String,
                     isIncoming: Bool,
                     date: Date,
                     channel: Channel,
                     isHidden: Bool = false,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: PhotoMessage.EntityName, in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.identifier = identifier
        self.thumbnail = thumbnail
        self.url = url
        self.xmppId = xmppId
        self.isIncoming = isIncoming
        self.date = date
        self.channel = channel
        self.isHidden = isHidden
    }
    
    private func thumbnailImage() throws -> UIImage {
        guard let image = UIImage(data: self.thumbnail) else {
            throw CoreData.Error.invalidMessage
        }
        
        return image
    }
    
    public override func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        do {
            let path = try CoreData.shared.getMediaStorage().getPath(name: self.identifier, type: .photo)
            
            let image: UIImage
            let state: MediaMessageState

            if let fullImage = UIImage(contentsOfFile: path) {
                image = fullImage
                state = .normal
            }
            else {
                image = try self.thumbnailImage()
                state = .downloading
            }

           let uiModel = UIPhotoMessageModel(uid: id,
                                             image: image,
                                             isIncoming: self.isIncoming,
                                             status: status,
                                             state: state,
                                             date: self.date)
            
            if state == .downloading {
                try Virgil.shared.client.startDownload(from: self.url,
                                                       loadDelegate: uiModel,
                                                       dataHash: self.identifier)
                { tempFileUrl in
                    guard let inputStream = InputStream(url: tempFileUrl) else {
                        throw Client.Error.inputStreamFromDownloadedFailed
                    }

                    guard let outputStream = OutputStream(toFileAtPath: path, append: false) else {
                        throw FileMediaStorage.Error.outputStreamToPathFailed
                    }

                    // TODO: add self card usecase
                    try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: self.channel.getCard())
                }
            }
            
            return uiModel
        }
        catch {
            Log.error(error, message: "Exporting PhotoMessage to UI model failed")
            
            return UITextMessageModel.corruptedModel(uid: id,
                                                     isIncoming: self.isIncoming,
                                                     date: self.date)
        }
    }
}