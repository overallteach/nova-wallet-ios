import UIKit

final class OperationDetailsPoolRewardView: LocalizableView {
    let poolTableView = StackTableView()
    let eventTableView = StackTableView()

    let poolView: StackInfoTableCell = .create { view in
        view.iconImageView.contentMode = .scaleAspectFit
    }

    let networkView = StackNetworkCell()

    let eventIdView = StackInfoTableCell()
    let typeView = StackTableCell()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindReward(viewModel: OperationPoolRewardOrSlashViewModel, networkViewModel: NetworkViewModel) {
        let type = R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
        bindCommon(viewModel: viewModel, networkViewModel: networkViewModel, type: type)
    }

    func bindSlash(viewModel: OperationPoolRewardOrSlashViewModel, networkViewModel: NetworkViewModel) {
        let type = R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        bindCommon(viewModel: viewModel, networkViewModel: networkViewModel, type: type)
    }

    private func bindCommon(
        viewModel: OperationPoolRewardOrSlashViewModel,
        networkViewModel: NetworkViewModel,
        type: String
    ) {
        bindPool(for: viewModel.pool)
        networkView.bind(viewModel: networkViewModel)
        eventIdView.bind(details: viewModel.eventId)
        typeView.bind(details: type)
    }

    private func bindPool(for poolViewModel: DisplayAddressViewModel?) {
        if let poolViewModel = poolViewModel {
            poolView.isHidden = false
            poolView.detailsLabel.lineBreakMode = poolViewModel.lineBreakMode
            poolView.bind(viewModel: poolViewModel.cellViewModel)
        } else {
            poolView.isHidden = true
        }
    }

    private func setupLocalization() {
        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)

        eventIdView.titleLabel.text = R.string.localizable.stakingCommonEventId(
            preferredLanguages: locale.rLanguages
        )

        typeView.titleLabel.text = R.string.localizable.stakingAnalyticsDetailsType(
            preferredLanguages: locale.rLanguages
        )

        poolView.titleLabel.text = R.string.localizable.stakingPool(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(poolTableView)
        poolTableView.snp.makeConstraints { make in
            make.top.trailing.leading.equalToSuperview()
        }

        poolTableView.addArrangedSubview(poolView)
        poolTableView.addArrangedSubview(networkView)

        addSubview(eventTableView)
        eventTableView.snp.makeConstraints { make in
            make.top.equalTo(poolTableView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        eventTableView.addArrangedSubview(eventIdView)
        eventTableView.addArrangedSubview(typeView)
    }
}
