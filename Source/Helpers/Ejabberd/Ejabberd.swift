//
//  Ejabberd.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 27.12.2019.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

class Ejabberd: NSObject {
    private(set) static var shared: Ejabberd = Ejabberd()

    // FIXME
    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal let stream: XMPPStream = XMPPStream()
    internal var error: Error?
    internal let initializeMutex: Mutex = Mutex()
    internal let sendMutex: Mutex = Mutex()
    internal let queue = DispatchQueue(label: "Ejabberd")

    override init() {
        super.init()

        self.stream.hostName = URLConstants.ejabberdHost
        self.stream.hostPort = URLConstants.ejabberdHostPort
        self.stream.startTLSPolicy = URLConstants.ejabberdTSLPolicy
        self.stream.addDelegate(self, delegateQueue: self.delegateQueue)

        try! self.initializeMutex.lock()
        try! self.sendMutex.lock()
    }

    public func initialize(identity: String) throws {
        self.stream.myJID = try Ejabberd.setupJid(with: identity)

        if !self.stream.isConnected {
            // FIME: Timeout
            try self.stream.connect(withTimeout: XMPPStreamTimeoutNone)
            try self.initializeMutex.lock()

            try self.checkError()
        }

        if !self.stream.isAuthenticated {
            try self.stream.authenticate(withPassword: "1111")
            try self.initializeMutex.lock()

            try self.checkError()
        }
    }

    private func checkError() throws {
        if let error = self.error {
            throw error
        }
    }

    internal func unlockMutex(_ mutex: Mutex, with error: Error? = nil) {
        do {
            self.error = error
            try mutex.unlock()
        }
        catch {
            Log.error("Ejabberd: \(error)")
        }
    }

    public static func setupJid(with username: String) throws -> XMPPJID {
        let jidString = "\(username)@\(URLConstants.ejabberdHost)"

        guard let jid = XMPPJID(string: jidString) else {
            throw NSError()
        }

        return jid
    }

    public func disconect() throws {
        Log.debug("Ejabberd: Disconnecting")

        guard self.stream.isConnected else {
            return
        }

        self.stream.disconnect()

        try self.initializeMutex.lock()

        try self.checkError()
    }

    public func send(_ message: EncryptedMessage, to user: String) throws {
        let user = try Ejabberd.setupJid(with: user)

        let body = try message.export()

        let message = XMPPMessage(messageType: .chat, to: user)
        message.addBody(body)

        self.stream.send(message)

        try self.sendMutex.lock()

        try self.checkError()
    }
}
