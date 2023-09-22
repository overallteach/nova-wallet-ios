import UIKit
import RobinHood
import SubstrateSdk
import BigInt

final class NPoolsClaimRewardsInteractor: RuntimeConstantFetching {
    weak var presenter: NPoolsClaimRewardsInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let signingWrapper: SigningWrapperProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?

    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signingWrapper: SigningWrapperProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.signingWrapper = signingWrapper
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    func setupPoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        rewardPoolProvider = subscribeRewardPool(for: poolId, chainId: chainId)

        setupClaimableRewardsProvider()
    }

    func setupClaimableRewardsProvider() {
        guard let poolId = currentPoolId else {
            return
        }

        claimableRewardProvider = subscribeClaimableRewards(
            for: chainId,
            poolId: poolId,
            accountId: accountId
        )

        if claimableRewardProvider == nil {
            presenter?.didReceive(error: .subscription(CommonError.dataCorruption, "rewards"))
        }
    }

    func setupCurrencyProvider() {
        guard let priceId = asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func setupBaseProviders() {
        rewardPoolProvider = nil
        claimableRewardProvider = nil

        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
        balanceProvider = subscribeToAssetBalanceProvider(for: accountId, chainId: chainId, assetId: assetId)

        setupCurrencyProvider()
    }

    func createExtrinsicBuilderClosure(
        for strategy: NominationPools.ClaimRewardsStrategy
    ) -> ExtrinsicBuilderClosure {
        { builder in
            switch strategy {
            case .restake:
                let bondExtra = NominationPools.BondExtraCall(extra: .rewards)
                return try builder.adding(call: bondExtra.runtimeCall())
            case .freeBalance:
                let claimRewards = NominationPools.ClaimRewardsCall()
                return try builder.adding(call: claimRewards.runtimeCall())
            }
        }
    }

    func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(existentialDeposit):
                self?.presenter?.didReceive(existentialDeposit: existentialDeposit)
            case let .failure(error):
                self?.presenter?.didReceive(error: .existentialDeposit(error))
            }
        }
    }
}

extension NPoolsClaimRewardsInteractor: NPoolsClaimRewardsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        setupBaseProviders()
        provideExistentialDeposit()
    }

    func remakeSubscriptions() {
        setupBaseProviders()
    }

    func retryExistentialDeposit() {
        provideExistentialDeposit()
    }

    func estimateFee(for strategy: NominationPools.ClaimRewardsStrategy) {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: strategy.rawValue,
            setupBy: createExtrinsicBuilderClosure(for: strategy)
        )
    }

    func submit(for strategy: NominationPools.ClaimRewardsStrategy) {
        extrinsicService.submit(
            createExtrinsicBuilderClosure(for: strategy),
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result)
        }
    }
}

extension NPoolsClaimRewardsInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            presenter?.didReceive(fee: BigUInt(dispatchInfo.fee))
        case let .failure(error):
            presenter?.didReceive(error: .fee(error))
        }
    }
}

extension NPoolsClaimRewardsInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            if currentPoolId != optPoolMember?.poolId {
                currentPoolId = optPoolMember?.poolId

                setupPoolProviders()
            }

            if currentMemberRewardCounter != optPoolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = optPoolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }

    func handleClaimableRewards(
        result: Result<BigUInt?, Error>,
        chainId _: ChainModel.Id,
        poolId _: NominationPools.PoolId,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(rewards):
            presenter?.didReceive(claimableRewards: rewards)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "rewards"))
        }
    }

    func handleRewardPool(
        result: Result<NominationPools.RewardPool?, Error>,
        poolId: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        guard currentPoolId == poolId else {
            return
        }

        if case let .success(rewardPool) = result, rewardPool?.lastRecordedRewardCounter != currentPoolRewardCounter {
            self.currentPoolRewardCounter = rewardPool?.lastRecordedRewardCounter

            claimableRewardProvider?.refresh()
        }
    }
}

extension NPoolsClaimRewardsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            // we can have case when user have np staking but no native balance
            let balanceOrZero = assetBalance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )

            presenter?.didReceive(assetBalance: balanceOrZero)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "balance"))
        }
    }
}

extension NPoolsClaimRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NPoolsClaimRewardsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupCurrencyProvider()
    }
}
