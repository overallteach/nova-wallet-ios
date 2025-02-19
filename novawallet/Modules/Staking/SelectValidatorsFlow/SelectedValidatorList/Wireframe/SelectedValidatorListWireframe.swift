class SelectedValidatorListWireframe: SelectedValidatorListWireframeProtocol {
    let stakingState: RelaychainStakingSharedStateProtocol

    init(stakingState: RelaychainStakingSharedStateProtocol) {
        self.stakingState = stakingState
    }

    func present(_ validatorInfo: ValidatorInfoProtocol, from view: ControllerBackedProtocol?) {
        guard let validatorInfoView = ValidatorInfoViewFactory.createView(
            with: validatorInfo,
            state: stakingState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func proceed(
        from _: SelectedValidatorListViewProtocol?,
        targets _: [SelectedValidatorInfo],
        maxTargets _: Int
    ) {}

    func dismiss(_ view: ControllerBackedProtocol?) {
        view?.controller
            .navigationController?
            .popViewController(animated: true)
    }
}
