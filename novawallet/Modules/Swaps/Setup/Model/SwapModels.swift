import SoraFoundation

struct SwapSetupFeeIdentifier: Equatable {
    let transactionId: String
    let feeChainAssetId: ChainAssetId?
}

struct DepositOperationModel {
    let operation: TokenOperation
    let active: Bool
}

extension DepositOperationModel {
    func titleForLocale(_ locale: Locale) -> String {
        switch operation {
        case .send:
            return R.string.localizable.swapsSetupDepositByCrossChainTransferTitle(
                preferredLanguages: locale.rLanguages
            )
        case .receive:
            return R.string.localizable.walletAssetReceive(
                preferredLanguages: locale.rLanguages
            )
        case .buy:
            return R.string.localizable.walletAssetBuy(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func subtitleForLocale(_ locale: Locale, token: String) -> String {
        switch operation {
        case .send:
            return R.string.localizable.swapsSetupDepositByCrossChainTransferSubtitle(
                token,
                preferredLanguages: locale.rLanguages
            )
        case .receive:
            return R.string.localizable.swapsSetupDepositByReceiveSubtitle(
                token,
                preferredLanguages: locale.rLanguages
            )
        case .buy:
            return R.string.localizable.swapsSetupDepositByBuySubtitle(
                token,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    var icon: UIImage? {
        switch operation {
        case .send:
            return R.image.iconCrossChainTransfer()
        case .receive:
            return R.image.iconReceive()
        case .buy:
            return R.image.iconBuy()
        }
    }
}
