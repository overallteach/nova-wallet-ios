import Foundation
import BigInt

final class StakingTypeWireframe: StakingTypeWireframeProtocol {
    let state: RelaychainStartStakingStateProtocol

    init(state: RelaychainStartStakingStateProtocol) {
        self.state = state
    }

    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showNominationPoolsList(
        from view: ControllerBackedProtocol?,
        amount: BigUInt,
        delegate: StakingSetupTypeEntityFacade,
        selectedPool: NominationPools.SelectedPool?
    ) {
        guard let poolListView = StakingSelectPoolViewFactory.createView(
            state: state,
            amount: amount,
            selectedPool: selectedPool,
            delegate: delegate
        ) else {
            return
        }

        delegate.bindToFlow(controller: poolListView.controller)

        view?.controller.navigationController?.pushViewController(
            poolListView.controller,
            animated: true
        )
    }

    func showValidators(
        from view: ControllerBackedProtocol?,
        selectionValidatorGroups: SelectionValidatorGroups,
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        validatorsSelectionParams: ValidatorsSelectionParams,
        delegate: StakingSetupTypeEntityFacade
    ) {
        guard let validatorsView = CustomValidatorListViewFactory.createValidatorListView(
            for: state,
            selectionValidatorGroups: selectionValidatorGroups,
            selectedValidatorList: selectedValidatorList,
            validatorsSelectionParams: validatorsSelectionParams,
            delegate: delegate
        ) else {
            return
        }

        delegate.bindToFlow(controller: validatorsView.controller)

        view?.controller.navigationController?.pushViewController(
            validatorsView.controller,
            animated: true
        )
    }
}
