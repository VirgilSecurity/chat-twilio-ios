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

import ChattoAdditions

protocol PhotoObserverProtocol: class {
    func showImage(_ : UIImage)
    func longPressOnImage(_ : UIImage, id: String, isIncoming: Bool)
}

class UIPhotoMessageHandler: NSObject, BaseMessageInteractionHandlerProtocol {
    func userDidSelectMessage(viewModel: UIPhotoMessageViewModel) {}

    func userDidDeselectMessage(viewModel: UIPhotoMessageViewModel) {}

    private let baseHandler: BaseMessageHandler
    weak private var photoObserverController: PhotoObserverProtocol!
    
    init (baseHandler: BaseMessageHandler, photoObserverController: PhotoObserverProtocol) {
        self.baseHandler = baseHandler
        self.photoObserverController = photoObserverController

        super.init()
    }

    func userDidTapOnFailIcon(viewModel: UIPhotoMessageViewModel, failIconView: UIView) {
        self.baseHandler.userDidTapOnFailIcon(viewModel: viewModel)
    }

    func userDidTapOnAvatar(viewModel: UIPhotoMessageViewModel) {
        self.baseHandler.userDidTapOnAvatar(viewModel: viewModel)
    }

    func userDidTapOnBubble(viewModel: UIPhotoMessageViewModel) {
        self.baseHandler.userDidTapOnBubble(viewModel: viewModel)

        if let image = viewModel.image.value {
            self.photoObserverController.showImage(image)
        }
    }

    func userDidBeginLongPressOnBubble(viewModel: UIPhotoMessageViewModel) {
        self.baseHandler.userDidBeginLongPressOnBubble(viewModel: viewModel)

        if let image = viewModel.image.value {
            self.photoObserverController.longPressOnImage(image,
                                                          id: viewModel.messageModel.uid,
                                                          isIncoming: viewModel.isIncoming)
        }
    }

    func userDidEndLongPressOnBubble(viewModel: UIPhotoMessageViewModel) {
        self.baseHandler.userDidEndLongPressOnBubble(viewModel: viewModel)
    }
}
