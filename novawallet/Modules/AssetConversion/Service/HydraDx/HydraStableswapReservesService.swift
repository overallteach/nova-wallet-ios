import Foundation
import SubstrateSdk
import RobinHood

final class HydraStableswapReservesService: ObservableSubscriptionSyncService<HydraStableswap.ReservesRemoteState> {
    let poolAsset: HydraDx.OmniPoolAssetId
    let otherAssets: [HydraDx.OmniPoolAssetId]
    let userAccountId: AccountId

    init(
        userAccountId: AccountId,
        poolAsset: HydraDx.OmniPoolAssetId,
        otherAssets: [HydraDx.OmniPoolAssetId],
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.userAccountId = userAccountId
        self.poolAsset = poolAsset
        self.otherAssets = otherAssets

        super.init(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            repository: repository,
            workQueue: workQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )
    }

    func getReserveRequests(
        for asset: HydraDx.OmniPoolAssetId,
        poolAccountId: AccountId
    ) -> [BatchStorageSubscriptionRequest] {
        let balanceRequest = BatchStorageSubscriptionRequest(
            innerRequest: DoubleMapSubscriptionRequest(
                storagePath: StorageCodingPath.ormlTokenAccount,
                localKey: "",
                keyParamClosure: {
                    (BytesCodable(wrappedValue: poolAccountId), StringScaleMapper(value: asset))
                }
            ),
            mappingKey: HydraStableswap.ReservesRemoteState.assetReserveKey(asset)
        )

        let decimalsRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraAssetRegistry.assetMetadata,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: asset)
                }
            ),
            mappingKey: HydraStableswap.ReservesRemoteState.assetMetadataKey(asset)
        )

        return [balanceRequest, decimalsRequest]
    }

    func getRequests(
        poolAsset: HydraDx.OmniPoolAssetId,
        otherAssets: [HydraDx.OmniPoolAssetId],
        userAccountId: AccountId,
        poolAccount: AccountId
    ) throws -> [BatchStorageSubscriptionRequest] {
        let poolAssetTotalIssuanceRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: StorageCodingPath.ormlTotalIssuance,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: poolAsset)
                }
            ),
            mappingKey: HydraStableswap.ReservesRemoteState.poolIssuanceKey
        )

        let poolShareRequest = BatchStorageSubscriptionRequest(
            innerRequest: DoubleMapSubscriptionRequest(
                storagePath: StorageCodingPath.ormlTokenAccount,
                localKey: "",
                keyParamClosure: {
                    (BytesCodable(wrappedValue: userAccountId), StringScaleMapper(value: poolAsset))
                }
            ),
            mappingKey: HydraStableswap.ReservesRemoteState.poolShareKey
        )

        let reserves = otherAssets.flatMap { getReserveRequests(for: $0, poolAccountId: poolAccount) }

        return [poolAssetTotalIssuanceRequest, poolShareRequest] + reserves
    }

    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        let poolAccountId = try HydraStableswap.poolAccountId(for: poolAsset)

        return try getRequests(
            poolAsset: poolAsset,
            otherAssets: otherAssets,
            userAccountId: userAccountId,
            poolAccount: poolAccountId
        )
    }
}
