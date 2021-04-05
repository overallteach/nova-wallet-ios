import Foundation
import RobinHood

struct WalletRemoteHistoryData {
    let historyItems: [WalletRemoteHistoryItemProtocol]
    let context: TransactionHistoryContext
}

protocol WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(for context: TransactionHistoryContext, address: String, count: Int)
        -> CompoundOperationWrapper<WalletRemoteHistoryData>
}

final class WalletRemoteHistoryFactory {
    struct MergeResult {
        let items: [WalletRemoteHistoryItemProtocol]
        let originalCounters: [WalletRemoteHistorySourceLabel: Int]
    }

    let internalFactory = SubscanOperationFactory()

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    private func createTransfersOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String
    ) -> BaseOperation<SubscanTransferData>? {
        guard !context.transfers.isComplete else {
            return nil
        }

        let transfersURL = baseURL.appendingPathComponent(SubscanApi.transfers)
        let transferInfo = HistoryInfo(
            address: address,
            row: context.transfers.row,
            page: context.transfers.page
        )
        return internalFactory.fetchTransfersOperation(transfersURL, info: transferInfo)
    }

    private func createRewardsOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String
    ) -> BaseOperation<SubscanRewardData>? {
        guard !context.rewards.isComplete else {
            return nil
        }

        let rewardsURL = baseURL.appendingPathComponent(SubscanApi.rewardsAndSlashes)
        let rewardInfo = HistoryInfo(
            address: address,
            row: context.rewards.row,
            page: context.rewards.page
        )
        return internalFactory.fetchRewardsAndSlashesOperation(rewardsURL, info: rewardInfo)
    }

    private func createExtrinsicsOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String
    ) -> BaseOperation<SubscanExtrinsicData>? {
        guard !context.extrinsics.isComplete else {
            return nil
        }

        let extrinsicsURL = baseURL.appendingPathComponent(SubscanApi.extrinsics)
        let info = HistoryInfo(
            address: address,
            row: context.extrinsics.row,
            page: context.extrinsics.page
        )
        return internalFactory.fetchExtrinsicsOperation(extrinsicsURL, info: info)
    }

    private func createMergeOperation(
        dependingOn transfersOperation: BaseOperation<SubscanTransferData>?,
        rewardsOperation: BaseOperation<SubscanRewardData>?,
        extrinsicsOperation: BaseOperation<SubscanExtrinsicData>?,
        context: TransactionHistoryContext
    ) -> BaseOperation<MergeResult> {
        ClosureOperation {
            let transferPageData = try transfersOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let rewardPageData = try rewardsOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let extrinsicPageData = try extrinsicsOperation?
                .extractNoCancellableResultData()

            let transfers = transferPageData?.transfers ?? []
            let rewards = rewardPageData?.items ?? []
            let extrinsics = extrinsicPageData?.extrinsics ?? []

            let completionMapping: [WalletRemoteHistorySourceLabel: Bool] =
                [
                    .transfers: transfers.count < context.transfers.row,
                    .rewards: rewards.count < context.rewards.row,
                    .extrinsics: extrinsics.count < context.extrinsics.row
                ]

            let originalCounters: [WalletRemoteHistorySourceLabel: Int] =
                [
                    .transfers: transfers.count,
                    .rewards: rewards.count,
                    .extrinsics: extrinsics.count
                ]

            let resultItems: [WalletRemoteHistoryItemProtocol] =
                (rewards + extrinsics + transfers).sorted { item1, item2 in
                    if item1.itemBlockNumber > item2.itemBlockNumber {
                        return true
                    } else if item1.itemBlockNumber < item2.itemBlockNumber {
                        return false
                    }

                    return item1.itemExtrinsicIndex >= item2.itemExtrinsicIndex
                }

            let transfersIndex = resultItems.lastIndex { $0.label == .transfers }
            let rewardsIndex = resultItems.lastIndex { $0.label == .rewards }
            let extrinsicsIndex = resultItems.lastIndex { $0.label == .extrinsics }

            let truncationLength =
                (
                    (transfersIndex.map { [(WalletRemoteHistorySourceLabel.transfers, $0)] } ?? []) +
                        (rewardsIndex.map { [(WalletRemoteHistorySourceLabel.rewards, $0)] } ?? []) +
                        (extrinsicsIndex.map { [(WalletRemoteHistorySourceLabel.extrinsics, $0)] } ?? [])
                )
                .sorted { $0.1 < $1.1 }
                .first { !(completionMapping[$0.0] ?? false) }
                .map { $0.1 + 1 }

            let truncatedItems: [WalletRemoteHistoryItemProtocol] = {
                if let length = truncationLength {
                    return Array(resultItems.prefix(length))
                } else {
                    return resultItems
                }
            }()

            return MergeResult(items: truncatedItems, originalCounters: originalCounters)
        }
    }

    private func createMapOperation(
        dependingOn mergeOperation: BaseOperation<MergeResult>,
        context: TransactionHistoryContext
    ) -> BaseOperation<WalletRemoteHistoryData> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let counters = mergeResult.items
                .reduce(into: [WalletRemoteHistorySourceLabel: Int]()) { result, item in
                    result[item.label] = (result[item.label] ?? 0) + 1
                }

            let nextContext = WalletRemoteHistorySourceLabel.allCases.reduce(context) { result, label in
                let sourceContext = result.sourceContext(for: label)

                guard !sourceContext.isComplete else {
                    return result
                }

                let filteredCount = counters[label] ?? 0
                let total = (sourceContext.page * sourceContext.row) + filteredCount
                let row = total.firstDivider(from: (1 ... result.defaultRow).reversed()) ?? 1
                let nextPage = total / row

                let originalCount = mergeResult.originalCounters[label] ?? 0
                let isCompleted = originalCount == filteredCount ? originalCount < sourceContext.row : false

                let nextSourceContext = result.sourceContext(for: label)
                    .byReplacingPage(nextPage)
                    .byReplacingRow(row)
                    .byReplacingCompletion(isCompleted)

                return result.byReplacingSource(context: nextSourceContext, for: label)
            }

            return WalletRemoteHistoryData(
                historyItems: mergeResult.items,
                context: nextContext
            )
        }
    }
}

extension WalletRemoteHistoryFactory: WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(for context: TransactionHistoryContext, address: String, count _: Int)
        -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard !context.isComplete else {
            let result = WalletRemoteHistoryData(historyItems: [], context: context)
            return CompoundOperationWrapper.createWithResult(result)
        }

        let transfersOperation = createTransfersOperationIfNeeded(for: context, address: address)
        let rewardsOperation = createRewardsOperationIfNeeded(for: context, address: address)
        let extrinsicsOperation = createExtrinsicsOperationIfNeeded(for: context, address: address)

        let sourceOperations = (transfersOperation.map { [$0] } ?? []) +
            (rewardsOperation.map { [$0] } ?? []) +
            (extrinsicsOperation.map { [$0] } ?? [])

        let mergeOperation = createMergeOperation(
            dependingOn: transfersOperation,
            rewardsOperation: rewardsOperation,
            extrinsicsOperation: extrinsicsOperation,
            context: context
        )

        sourceOperations.forEach { mergeOperation.addDependency($0) }

        let mapOperation = createMapOperation(dependingOn: mergeOperation, context: context)

        mapOperation.addDependency(mergeOperation)

        let dependencies = sourceOperations + [mergeOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
