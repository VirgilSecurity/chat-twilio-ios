//
//  VoiceCall.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/3/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class VoiceCallViewController: ViewController {
    @IBOutlet weak var signalingStatusLabel: UILabel!
    @IBOutlet weak var localSDPLabel: UILabel!
    @IBOutlet weak var localCandidatesLabel: UILabel!
    @IBOutlet weak var remoteSDPLabel: UILabel!
    @IBOutlet weak var remoteCandidatesLabel: UILabel!
    @IBOutlet weak var webRtcStatusLabel: UILabel!
    
    @IBAction func sendOfferTapped(_ sender: Any) {
        // TODO: Implement me
        Log.debug("Send Offer tapped")
    }
    
    @IBAction func sendAnswerTapped(_ sender: Any) {
        // TODO: Implement me
        Log.debug("Send Answer tapped")
    }
}
