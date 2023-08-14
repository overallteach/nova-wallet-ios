import Foundation
import SubstrateSdk
import SoraKeystore

final class DAppSignBytesConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel
    let signingWrapperFactory: SigningWrapperFactoryProtocol

    private(set) var account: ChainAccountResponse?

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        signingWrapperFactory: SigningWrapperFactoryProtocol
    ) {
        self.request = request
        self.chain = chain
        self.signingWrapperFactory = signingWrapperFactory
    }

    private func validateAndProvideConfirmationModel() {
        guard
            let accountResponse = request.wallet.fetchByAccountId(
                request.accountId,
                request: chain.accountRequest()
            ),
            let chainAddress = accountResponse.toAddress() else {
            presenter?.didReceive(feeResult: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        account = accountResponse

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: accountResponse.accountId,
            chainAddress: chainAddress,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))
    }

    private func provideZeroFee() {
        let feeModel = DAppOperationConfirmFee(value: 0, validationProvider: nil)
        presenter?.didReceive(feeResult: .success(feeModel))
        presenter?.didReceive(priceResult: .success(nil))
    }

    private func prepareRawBytes() throws -> Data {
        if case let .stringValue(stringValue) = request.operationData {
            if stringValue.isHex() {
                return try Data(hexString: stringValue)
            } else {
                guard let data = stringValue.data(using: .utf8) else {
                    throw CommonError.dataCorruption
                }

                return data
            }

        } else {
            return try JSONEncoder().encode(request.operationData)
        }
    }
}

extension DAppSignBytesConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        validateAndProvideConfirmationModel()

        provideZeroFee()
    }

    func estimateFee() {
        provideZeroFee()
    }

    func confirm() {
        guard let account = account else {
            return
        }

        do {
            if let notSupportedSigner = account.type.notSupportedRawBytesSigner {
                throw NoSigningSupportError.notSupported(type: notSupportedSigner)
            }

            let signer = signingWrapperFactory.createSigningWrapper(
                for: request.wallet.metaId,
                accountResponse: account
            )

            let rawBytes = try prepareRawBytes()

            let signature = try signer.sign(rawBytes).rawData()

            let response = DAppOperationResponse(signature: signature)

            presenter?.didReceive(responseResult: .success(response), for: request)
        } catch {
            presenter?.didReceive(responseResult: .failure(error), for: request)
        }
    }

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func prepareTxDetails() {
        presenter?.didReceive(txDetailsResult: .success(request.operationData))
    }
}
