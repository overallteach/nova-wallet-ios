import UIKit
import SnapKit

final class ProxyIconView: UIView {
    enum Constants {
        static let holeWidth: CGFloat = 3
        static let iconSize = CGSize(width: 32, height: 32)
        static let networkIconSize = CGSize(width: 14, height: 14)
        static let networkIconOffset = CGPoint(x: 6, y: 4)
        static let radius: CGFloat = 4.5
    }

    let iconViewImageView = UIImageView()
    let networkIconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        iconViewImageView.layoutIfNeeded()

        let width = networkIconImageView.bounds.width + Constants.holeWidth * 2
        let height = networkIconImageView.bounds.height + Constants.holeWidth * 2
        let origin = convert(networkIconImageView.frame.origin, to: iconViewImageView)

        let frame = CGRect(
            x: origin.x - Constants.holeWidth,
            y: origin.y - Constants.holeWidth,
            width: width,
            height: height
        )

        iconViewImageView.makeRoundedRectangularHole(
            roundedRect: frame,
            cornerRadii: CGSize(
                width: Constants.radius + Constants.holeWidth / 2,
                height: Constants.radius + Constants.holeWidth / 2
            )
        )
    }

    func setupLayout() {
        addSubview(iconViewImageView)

        iconViewImageView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(Constants.iconSize)
        }

        networkIconImageView.layer.cornerRadius = Constants.radius
        addSubview(networkIconImageView)

        networkIconImageView.snp.makeConstraints {
            $0.trailing.equalTo(networkIconImageView.snp.trailing).offset(Constants.networkIconOffset.x)
            $0.bottom.equalTo(networkIconImageView.snp.bottom).offset(Constants.networkIconOffset.y)
            $0.size.equalTo(Constants.networkIconSize)
        }
    }
}

extension UIView {
    func makeRoundedRectangularHole(roundedRect: CGRect, cornerRadii: CGSize) {
        let entireViewPath = UIBezierPath(rect: bounds)

        let roundedRectPath = UIBezierPath(
            roundedRect: roundedRect,
            byRoundingCorners: .allCorners,
            cornerRadii: cornerRadii
        )
        entireViewPath.append(roundedRectPath)
        entireViewPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = entireViewPath.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        maskLayer.fillColor = UIColor.black.cgColor
        layer.mask = maskLayer
    }
}
