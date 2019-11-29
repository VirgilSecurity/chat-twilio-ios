//
//  UsersListCell.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/15/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import VirgilSDK

class UsersListCell: UITableViewCell {
    static let name = "UsersListCell"

    weak var delegate: CellTapDelegate?

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.didTap)))
    }

    @objc func didTap() {
        self.delegate?.didTapOn(self)
    }

    public func configure(with cards: [Card]) {
        guard let card = cards[safe: self.tag] else {
            return
        }

        let name = card.identity

        self.usernameLabel.text = name

        if let channel = CoreData.shared.getSingleChannel(with: name) {
            self.letterLabel.text = channel.letter
            self.avatarView.draw(with: channel.colors)
        }
        else {
            self.letterLabel.text = String(describing: name.uppercased().first!)

            let numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
            let colorPair = UIConstants.colorPairs[Int(numColorPair)]
            let colors = [colorPair.first, colorPair.second]
            self.avatarView.draw(with: colors)
        }
    }
}
