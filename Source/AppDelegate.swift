//
//  AppDelegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UserNotifications
import UIKit
import VirgilSDK
import Firebase
import CocoaLumberjackSwift
import WebRTC
import PushKit
import CallKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var pushNotificationsDelegate = PushNotificationsDelegate()
    weak var callProviderDelegate: CXProviderDelegate?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Firebase configuration for Crashlytics
        FirebaseApp.configure()

        // WebRTC
        RTCInitializeSSL()

        // Defining start controller
        let startStoryboard = UIStoryboard(name: StartViewController.name, bundle: Bundle.main)
        let startController = startStoryboard.instantiateInitialViewController()!

        let logger = DDOSLogger.sharedInstance
        DDLog.add(logger, with: .all)

        self.window?.rootViewController = startController

        // Clear core data if it's first launch
        self.cleanLocalStorage()

        // Registering for remote notifications
        self.registerRemoteNotifications(for: application)

        // Clean notifications
        self.cleanNotifications()

        // Registering for Voip notifications
        self.registerVoip()

        return true
    }

    private func registerVoip() {
        self.callProviderDelegate = CallManager.shared

        let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }

    private func cleanLocalStorage() {
        do {
            let key = Storage.dbName

            if UserDefaults.standard.string(forKey: key)?.isEmpty ?? true {
                try? Storage.shared.clearStorage()

                // Clean keychain
                let params = try KeychainStorageParams.makeKeychainStorageParams()
                let keychain = KeychainStorage(storageParams: params)

                try keychain.deleteAllEntries()

                UserDefaults.standard.set("initialized", forKey: key)
                UserDefaults.standard.synchronize()
            }
        } catch {
            Log.error(error, message: "Clean Local Storage on startup failed")
        }
    }

    private func registerRemoteNotifications(for app: UIApplication) {
        let center = UNUserNotificationCenter.current()

        center.delegate = pushNotificationsDelegate

        center.getNotificationSettings { settings in

            if settings.authorizationStatus == .notDetermined {

                center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, _) in
                    Log.debug("User allowed notifications: \(granted)")

                    if granted {
                        DispatchQueue.main.async {
                            app.registerForRemoteNotifications()
                        }
                    }
                }

            } else if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    app.registerForRemoteNotifications()
                }
            }
        }
    }

    private func cleanNotifications() {
        PushNotifications.cleanNotifications()
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.debug("Received notification")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        RTCCleanupSSL()
        do {
            try Storage.shared.saveContext()
        }
        catch {
            Log.error(error, message: "Saving Core Data context on app termination failed")
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.debug("Received device token: \(deviceToken.hexEncodedString())")

        do {
            if Ejabberd.shared.state == .connected {
                try Ejabberd.shared.registerForNotifications(deviceToken: deviceToken)
            }

            Ejabberd.updatedPushToken = deviceToken
        } catch {
            Log.error(error, message: "Registering for notification failed")
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error(error, message: "Failed to get device token")

        Ejabberd.updatedPushToken = nil
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Ejabberd.shared.set(status: .online)

        self.cleanNotifications()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Ejabberd.shared.set(status: .unavailable)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        UnreadManager.shared.update()
    }
}

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type != .voIP {
            return
        }

        let deviceToken = pushCredentials.token

        do {
            if Ejabberd.shared.state == .connected {
                try Ejabberd.shared.registerForNotifications(voipDeviceToken: deviceToken)
            }

            Ejabberd.updatedVoipPushToken = deviceToken
        } catch {
            Log.error(error, message: "Registering for VoIP notifications failed")
        }
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        if type != .voIP {
            return
        }

        guard
            let aps = payload.dictionaryPayload["aps"] as? NSDictionary,
            let alert = aps["alert"] as? NSDictionary,
            let caller = alert["title"] as? String,
            let body = alert["body"] as? String
        else {
            return
        }

        do {
            let encryptedMessage = try EncryptedMessage.import(body)

            try MessageProcessor.process(call: encryptedMessage, from: caller)
        }
        catch {
            Log.error(error, message: "Incomming call processing failed")
        }

        completion()
    }
}
