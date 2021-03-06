//
//  AddMembers.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/6/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD
import VirgilSDK

class AddMembersViewController: ViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIBarButtonItem!

    private var channels: [Storage.Channel] = []

    private var selected: [Storage.Channel] = [] {
        didSet {
            self.addButton.isEnabled = !self.selected.isEmpty
        }
    }

    public var dataSource: DataSource!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupTableView()
        self.setupObservers()
    }

    private func setupObservers() {
        let popToRoot: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.popToRoot()
            }
        }

        let reloadTableView: Notifications.Block = { [weak self] _ in
            self?.reloadTableView()
        }

        Notifications.observe(for: .currentChannelDeleted, block: popToRoot)
        Notifications.observe(for: .messageAddedToCurrentChannel, block: reloadTableView)
    }

    private func setupTableView() {
        let chatListCellNib = UINib(nibName: ChooseMembersCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChooseMembersCell.name)

        self.tableView.rowHeight = 60
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self

        self.reloadTableView()
    }

    @objc private func reloadTableView() {
        self.channels = Storage.shared.getSingleChannels()

        self.channels = self.channels.filter { channel in
            // FIXME
            !Storage.shared.currentChannel!.cards.contains { card in
                channel.cards.first?.identity == card.identity
            }
        }

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @IBAction func addTapped(_ sender: Any) {
        let add = self.selected.map { $0.name }

        guard
            !add.isEmpty,
            self.checkReachability(),
            Configurator.isUpdated
        else {
            return
        }
    }
}

extension AddMembersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.channels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChooseMembersCell.name) as! ChooseMembersCell

        cell.tag = indexPath.row
        cell.delegate = self

        cell.configure(with: self.channels, selected: selected)

        return cell
    }
}

extension AddMembersViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let cell = cell as? ChooseMembersCell {
            let channel = self.channels[cell.tag]

            if cell.isMember {
                self.selected.append(channel)
            }
            else {
                self.selected = self.selected.filter { $0 != channel }
            }
        }
    }
}
