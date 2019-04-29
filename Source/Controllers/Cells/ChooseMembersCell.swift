//
//  ChooseMembersCell.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/11/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class ChooseMembersCell: UITableViewCell {
    static let name = "ChooseMembersCell"

    weak var delegate: CellTapDelegate?

    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var radioButton: UILabel!

    public var isMember: Bool {
        return !(self.radioButton.tag == 0)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.didTap)))
    }

    @objc func didTap() {
        self.switchMembership()

        self.delegate?.didTapOn(self)
    }

    private func switchMembership() {
        self.radioButton.tag = (self.radioButton.tag + 1) % 2
        self.radioButton.text = self.isMember ? "Member" : "-"
    }

    public func configure(with users: [Channel]) {
        guard let user = users[safe: self.tag] else {
            return
        }

        self.usernameLabel.text = user.name
        self.letterLabel.text = user.letter
        self.avatarView.gradientLayer.colors = [user.colorPair.first, user.colorPair.second]
        self.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()
    }
}