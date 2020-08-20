import UIKit
import SoraUI

final class ProfileTableViewCell: UITableViewCell {

    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!

    private(set) var viewModel: ProfileOptionViewModelProtocol?

    func bind(viewModel: ProfileOptionViewModelProtocol) {
        self.viewModel = viewModel

        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.accessoryTitle
    }
}
