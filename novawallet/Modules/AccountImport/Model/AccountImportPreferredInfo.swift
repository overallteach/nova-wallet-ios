import Foundation

struct MetaAccountImportPreferredInfo {
    let username: String?
    let cryptoType: MultiassetCryptoType?
    let genesisHash: Data?
    let substrateDeriviationPath: String?
    let evmDeriviationPath: String?
    let source: SecretSource
}
