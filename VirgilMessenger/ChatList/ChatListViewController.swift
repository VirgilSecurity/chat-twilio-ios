//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit

class ChatListViewController: UIViewController, UITableViewDataSource, CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        let username = self.usernames[cell.tag]
        self.goToChat(withUsername: username)
    }
    
    private func goToChat(withUsername username: String) {
        self.performSegue(withIdentifier: "goToChat", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let chatController = segue.destination as? DemoChatViewController {
            let initialCount = 10000
            let pageSize = 50
    
            let dataSource = FakeDataSource(count: initialCount, pageSize: pageSize)
            chatController.dataSource = dataSource
            chatController.messageSender = dataSource.messageSender
        }
    }
    
    static let name = "ChatList"
    
    @IBOutlet weak var tableView: UITableView!
    
    private let usernames = [
        "name1@gmail.com",
        "name2@gmail.com",
        "name3@gmail.com"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        self.tableView.register(UINib(nibName: ChatListCell.name, bundle: Bundle.main), forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 45
        self.tableView.tableFooterView = UIView(frame: .zero)
        
        self.tableView.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.name) as! ChatListCell
        
        cell.usernameLabel.text = self.usernames[indexPath.row]
        cell.tag = indexPath.row
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.usernames.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}
