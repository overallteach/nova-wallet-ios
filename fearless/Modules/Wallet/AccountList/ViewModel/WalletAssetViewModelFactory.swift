import Foundation
import CommonWallet
import RobinHood
import SoraFoundation
import FearlessUtils

final class WalletAssetViewModelFactory {
    let address: String
    let assetCellStyleFactory: AssetCellStyleFactoryProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let priceAsset: WalletAsset
    let accountCommandFactory: WalletSelectAccountCommandFactoryProtocol

    init(address: String,
         assetCellStyleFactory: AssetCellStyleFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         priceAsset: WalletAsset,
         accountCommandFactory: WalletSelectAccountCommandFactoryProtocol) {
        self.address = address
        self.assetCellStyleFactory = assetCellStyleFactory
        self.amountFormatterFactory = amountFormatterFactory
        self.priceAsset = priceAsset
        self.accountCommandFactory = accountCommandFactory
    }

    private func creatRegularViewModel(for asset: WalletAsset,
                                       balance: BalanceData,
                                       commandFactory: WalletCommandFactoryProtocol,
                                       locale: Locale) -> AssetViewModelProtocol? {
        let style = assetCellStyleFactory.createCellStyle(for: asset)

        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)
            .value(for: locale)

        let priceFormater = amountFormatterFactory.createTokenFormatter(for: priceAsset)
            .value(for: locale)

        let decimalBalance = balance.balance.decimalValue
        let amount: String

        if let balanceString = amountFormatter.string(from: decimalBalance as NSNumber) {
            amount = balanceString
        } else {
            amount = balance.balance.stringValue
        }

        let platform: String = asset.platform?.value(for: locale) ?? ""

        let balanceContext = BalanceContext(context: balance.context ?? [:])

        let priceString = priceFormater.string(from: balanceContext.price) ?? ""

        let totalPrice = balanceContext.price * balance.balance.decimalValue
        let totalPriceString = priceFormater.string(from: totalPrice)

        let priceChangeString = NumberFormatter.percent
            .string(from: balanceContext.priceChange as NSNumber) ?? ""

        let priceChangeViewModel = balanceContext.priceChange >= 0.0 ?
            WalletPriceChangeViewModel.goingUp(displayValue: priceChangeString) :
            WalletPriceChangeViewModel.goingDown(displayValue: priceChangeString)

        let imageViewModel: WalletImageViewModelProtocol?

        if let assetId = WalletAssetId(rawValue: asset.identifier), let icon = assetId.assetIcon {
            imageViewModel = WalletStaticImageViewModel(staticImage: icon)
        } else {
            imageViewModel = nil
        }

        let assetDetailsCommand = commandFactory.prepareAssetDetailsCommand(for: asset.identifier)
        assetDetailsCommand.presentationStyle = .push(hidesBottomBar: true)

        return WalletAssetViewModel(assetId: asset.identifier,
                                    amount: amount,
                                    symbol: asset.symbol,
                                    accessoryDetails: totalPriceString,
                                    imageViewModel: imageViewModel,
                                    style: style,
                                    platform: platform,
                                    details: priceString,
                                    priceChangeViewModel: priceChangeViewModel,
                                    command: assetDetailsCommand)
    }

    private func createTotalPriceViewModel(for asset: WalletAsset,
                                           balance: BalanceData,
                                           commandFactory: WalletCommandFactoryProtocol,
                                           locale: Locale) -> AssetViewModelProtocol? {
        let style = assetCellStyleFactory.createCellStyle(for: asset)

        let priceFormater = amountFormatterFactory.createTokenFormatter(for: priceAsset)
            .value(for: locale)

        let decimalBalance = balance.balance.decimalValue
        let amount: String

        if let balanceString = priceFormater.string(from: decimalBalance) {
            amount = balanceString
        } else {
            amount = balance.balance.stringValue
        }

        let iconGenerator = PolkadotIconGenerator()
        let icon = (try? iconGenerator.generateFromAddress(address))?
            .imageWithFillColor(R.color.colorWhite()!,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)

        let imageViewModel: WalletImageViewModelProtocol?

        if let accountIcon = icon {
            imageViewModel = WalletStaticImageViewModel(staticImage: accountIcon)
        } else {
            imageViewModel = nil
        }

        let details = R.string.localizable
            .walletAssetsTotalTitle(preferredLanguages: locale.rLanguages)

        let accountCommand = accountCommandFactory.createCommand(commandFactory)

        return WalletTotalPriceViewModel(assetId: asset.identifier,
                                         details: details,
                                         amount: amount,
                                         imageViewModel: imageViewModel,
                                         style: style,
                                         command: nil,
                                         accountCommand: accountCommand)
    }
}

extension WalletAssetViewModelFactory: AccountListViewModelFactoryProtocol {
    func createAssetViewModel(for asset: WalletAsset,
                              balance: BalanceData,
                              commandFactory: WalletCommandFactoryProtocol,
                              locale: Locale) -> WalletViewModelProtocol? {
        if asset.identifier == priceAsset.identifier {
            return createTotalPriceViewModel(for: asset,
                                             balance: balance,
                                             commandFactory: commandFactory,
                                             locale: locale)
        } else {
            return creatRegularViewModel(for: asset,
                                         balance: balance,
                                         commandFactory: commandFactory,
                                         locale: locale)
        }
    }
}
