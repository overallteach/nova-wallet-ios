import Foundation
import SoraUI
import CommonWallet

final class WalletActionsCell: UICollectionViewCell {
    @IBOutlet private var sendButton: TriangularedBlurButton!
    @IBOutlet private var receiveButton: TriangularedBlurButton!
    @IBOutlet private var buyButton: TriangularedBlurButton!

    private(set) var actionsViewModel: WalletActionsViewModelProtocol?

    override func prepareForReuse() {
        super.prepareForReuse()

        actionsViewModel = nil
    }

    @IBAction private func actionSend() {
        if let actionsViewModel = actionsViewModel {
            try? actionsViewModel.send.command.execute()
        }
    }

    @IBAction private func actionReceive() {
        if let actionsViewModel = actionsViewModel {
            try? actionsViewModel.receive.command.execute()
        }
    }

    @IBAction private func actionBuy() {
        if let command = actionsViewModel?.buy?.command {
            try? command.execute()
        }
    }
}

extension WalletActionsCell: WalletViewProtocol {
    var viewModel: WalletViewModelProtocol? {
        return actionsViewModel
    }

    func bind(viewModel: WalletViewModelProtocol) {
        if let actionsViewModel = viewModel as? WalletActionsViewModelProtocol {
            self.actionsViewModel = actionsViewModel

            sendButton.imageWithTitleView?.title = actionsViewModel.send.title
            receiveButton.imageWithTitleView?.title = actionsViewModel.receive.title
            buyButton.imageWithTitleView?.title = actionsViewModel.buy?.title

            sendButton.invalidateLayout()
            receiveButton.invalidateLayout()
            buyButton.invalidateLayout()
        }
    }
}
