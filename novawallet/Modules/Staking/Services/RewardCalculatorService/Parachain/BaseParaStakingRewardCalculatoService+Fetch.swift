import Foundation

extension BaseParaStakingRewardCalculatoService {
    func updateTotalStaked() {
        totalStakedService?.throttle()
        totalStakedService = nil

        let storagePath = ParachainStaking.totalPath

        guard let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainId: chainId
        ) else {
            logger.error("Can't encode local key")
            return
        }

        let repository = repositoryFactory.createChainStorageItemRepository()

        let request = UnkeyedSubscriptionRequest(storagePath: storagePath, localKey: localKey)

        totalStakedService = StorageItemSyncService(
            chainId: chainId,
            storagePath: storagePath,
            request: request,
            repository: repository,
            connection: connection,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            logger: logger,
            completionQueue: syncQueue
        ) { [weak self] totalStaked in
            if let totalStaked = totalStaked?.value {
                self?.didUpdateTotalStaked(totalStaked)
            }
        }

        totalStakedService?.setup()
    }
}
