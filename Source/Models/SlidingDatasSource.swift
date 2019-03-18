/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import Foundation

public enum InsertPosition {
    case top
    case bottom
}

public class SlidingDataSource<Element> {
    private var pageSize: Int
    private var windowOffset: Int
    private var windowCount: Int
    private(set) var itemGenerator: ((Int, NSOrderedSet) -> Element)
    private(set) var items = [Element]()
    private var itemsOffset: Int
    public var itemsInWindow: [Element] {
        let offset = self.windowOffset - self.itemsOffset
        let a = offset < 0 ? 0 : offset
        var b = a + self.windowCount + abs(offset)
        b = b > items.count ? items.count : b

        return Array(items[a..<b])
    }

    init(count: Int, pageSize: Int, itemGenerator: @escaping ((Int, NSOrderedSet) -> Element)) {
        self.windowOffset = count
        self.itemsOffset = count
        self.windowCount = 0
        self.itemGenerator = itemGenerator
        self.pageSize = pageSize
        self.showItems(min(pageSize, count), position: .top)
    }

    private func showItems(_ count: Int, position: InsertPosition) {
        guard count > 0 else { return }
        guard let channel = CoreDataHelper.shared.currentChannel,
            let messages = channel.message else {
                Log.error("Missing Core Data current channel")
                return
        }
        for _ in 0..<count {
            let messageNumber = messages.count - self.items.count - 1
            if messageNumber >= 0 {
                self.insertItem(itemGenerator(messages.count - self.items.count - 1, messages), position: position)
            }
        }
    }

    public func insertItem(_ item: Element, position: InsertPosition) {
        if position == .top {
            self.items.insert(item, at: 0)
            let shouldExpandWindow = self.itemsOffset == self.windowOffset
            self.itemsOffset -= 1
            if shouldExpandWindow {
                self.windowOffset -= 1
                self.windowCount += 1
            }
        } else {
            let shouldExpandWindow = self.itemsOffset + self.items.count == self.windowOffset + self.windowCount
            if shouldExpandWindow {
                self.windowCount += 1
            }
            self.items.append(item)
        }
    }

    public func hasPrevious() -> Bool {
        return self.windowOffset > 0
    }

    public func hasMore() -> Bool {
        return self.windowOffset + self.windowCount < self.itemsOffset + self.items.count
    }

    public func loadPrevious() {
        let previousWindowOffset = self.windowOffset
        let previousWindowCount = self.windowCount
        let nextWindowOffset = max(0, self.windowOffset - self.pageSize)
        let messagesNeeded = self.itemsOffset - nextWindowOffset

        if messagesNeeded > 0 {
            self.showItems(messagesNeeded, position: .top)
        }

        let newItemsCount = previousWindowOffset - nextWindowOffset
        self.windowOffset = nextWindowOffset
        self.windowCount = previousWindowCount + newItemsCount
    }

    public func loadNext() {
        guard !self.items.isEmpty else { return }
        let itemCountAfterWindow = self.itemsOffset + self.items.count - self.windowOffset - self.windowCount
        self.windowCount += min(self.pageSize, itemCountAfterWindow)
    }

    @discardableResult
    public func adjustWindow(focusPosition: Double, maxWindowSize: Int) -> Bool {
        assert(0 <= focusPosition && focusPosition <= 1, "")
        guard 0 <= focusPosition && focusPosition <= 1 else {
            assert(false, "focus should be in the [0, 1] interval")
            return false
        }
        let sizeDiff = self.windowCount - maxWindowSize
        guard sizeDiff > 0 else { return false }
        self.windowOffset += Int(focusPosition * Double(sizeDiff))
        self.windowCount = maxWindowSize
        return true
    }
}
