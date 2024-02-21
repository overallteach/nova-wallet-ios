import Foundation

enum NftType: UInt16, Equatable {
    case uniques // kodadot type now covers uniques
    case rmrkV1 // this type was deprecated but we keep him for cache purpose
    case rmrkV2
    case pdc20
    case kodadot

    static var notIntersectingTypes: Set<NftType> {
        [rmrkV1, rmrkV2, pdc20, kodadot]
    }
}
