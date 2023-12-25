import Foundation
import SoraFoundation

struct WalletSelectionViewFactory {
    static func createView() -> WalletsListViewProtocol? {
        guard let interactor = createInteractor(),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = WalletSelectionWireframe()

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let presenter = WalletSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletSelectionViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.baseView = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> WalletSelectionInteractor? {
        guard let balancesStore = BalancesStore.createDefault() else {
            return nil
        }

        let userDataStorageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: userDataStorageFacade)
        let metaAccountsRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )
        let proxySyncService = ProxySyncService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            userDataStorageFacade: userDataStorageFacade,
            proxyOperationFactory: ProxyOperationFactory(),
            metaAccountsRepository: metaAccountsRepository
        )

        return WalletSelectionInteractor(
            balancesStore: balancesStore,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            proxySyncService: proxySyncService,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )
    }
}
