import Foundation
import SoraFoundation

struct NotificationWalletListViewFactory {
    static func createView(
        initState: [Web3AlertWallet]?,
        completion: @escaping ([Web3AlertWallet]) -> Void
    ) -> NotificationWalletListViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let interactor = NotificationWalletListInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared
        )
        let wireframe = NotificationWalletListWireframe(completion: completion)

        let presenter = NotificationWalletListPresenter(
            initState: initState,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localPushSettingsFactory: LocalPushSettingsFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = NotificationWalletListViewController(
            presenter: presenter,

            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
