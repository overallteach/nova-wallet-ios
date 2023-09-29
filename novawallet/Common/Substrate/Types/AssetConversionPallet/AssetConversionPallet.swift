import Foundation
import SubstrateSdk
import BigInt

enum AssetConversionPallet {
    static let name = "AssetConversion"

    enum PoolAsset {
        case native
        case assets(pallet: UInt8, index: BigUInt)
        case foreignNetwork(XcmV3.NetworkId)
        case undefined(XcmV3.Multilocation)

        init(multilocation: XcmV3.Multilocation) {
            let junctions = multilocation.interior.items

            if multilocation.parents == 0 {
                guard !junctions.isEmpty else {
                    self = .native
                    return
                }

                switch junctions[0] {
                case let .palletInstance(pallet):
                    if
                        junctions.count == 2,
                        case let .generalIndex(index) = junctions[1] {
                        self = .assets(pallet: pallet, index: index)
                    } else {
                        self = .undefined(multilocation)
                    }
                default:
                    self = .undefined(multilocation)
                }
            } else if multilocation.parents == 2, junctions.count == 1 {
                switch junctions[0] {
                case let .globalConsensus(network):
                    self = .foreignNetwork(network)
                default:
                    self = .undefined(multilocation)
                }
            } else {
                self = .undefined(multilocation)
            }
        }
    }

    struct PoolAssetPair: JSONListConvertible {
        let asset1: PoolAsset
        let asset2: PoolAsset

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            let multilocation1 = try jsonList[0].map(to: XcmV3.Multilocation.self, with: context)
            let multilocation2 = try jsonList[1].map(to: XcmV3.Multilocation.self, with: context)

            asset1 = PoolAsset(multilocation: multilocation1)
            asset2 = PoolAsset(multilocation: multilocation2)
        }
    }
}
