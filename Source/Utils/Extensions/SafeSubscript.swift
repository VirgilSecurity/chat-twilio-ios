//
//  Utils+SafeSubscript.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/7/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
