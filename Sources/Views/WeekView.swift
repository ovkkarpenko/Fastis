//
//  FastisWeekView.swift
//  Fastis
//
//  Created by Ilya Kharlamov on 10.04.2020.
//  Copyright © 2020 DIGITAL RETAIL TECHNOLOGIES, S.L. All rights reserved.
//

import UIKit

final class WeekView: UIView {

    // MARK: - Outlets

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.backgroundColor = .clear
        stackView.spacing = 0
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Variables

    private var config: FastisConfig.WeekView
    private var calendar: Calendar

    // MARK: - Lifecycle

    init(calendar: Calendar, config: FastisConfig.WeekView) {
        self.config = config
        self.calendar = calendar
        super.init(frame: .zero)
        self.configureUI()
        self.configureSubviews()
        self.configureConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(calendar: Calendar, config: FastisConfig.WeekView) {
        self.config = config
        self.calendar = calendar
        
        self.configureUI()
        self.configureSubviews()
        self.configureConstraints()
    }
    
    // MARK: - Configuration

    private func configureUI() {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = self.config.backgroundColor
        self.layer.cornerRadius = self.config.cornerRadius
    }

    private func configureSubviews() {
        stackView.removeFromSuperview()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let numDays = self.calendar.shortStandaloneWeekdaySymbols.count
        let first = self.calendar.firstWeekday - 1
        let end = first + numDays - 1
        let days = (first ... end).map({ self.calendar.shortStandaloneWeekdaySymbols[$0 % numDays] })
        for weekdaySymbol in days {
            self.stackView.addArrangedSubview(self.makeWeekLabel(for: weekdaySymbol))
        }
        self.addSubview(self.stackView)
    }

    func makeWeekLabel(for symbol: String) -> UILabel {
        let label = UILabel()
        if self.config.uppercaseWeekName,
           let first: Character = symbol.first,
           let last: Character = symbol.last {
            label.text = "\(first.uppercased())\(last.lowercased())"
        } else {
            label.text = symbol
        }
        label.font = self.config.textFont
        label.textColor = self.config.textColor
        label.textAlignment = .center
        return label
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            self.stackView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 4),
            self.stackView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -4),
            self.stackView.topAnchor.constraint(equalTo: self.topAnchor),
            self.stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: self.config.height)
        ])
    }

}

public extension FastisConfig {

    /**
     Top header view with week day names

     Configurable in FastisConfig.``FastisConfig/weekView-swift.property`` property
     */
    struct WeekView {

        /**
         Background color of the view

         Default value — `.secondarySystemBackground`
         */
        public var backgroundColor: UIColor = .secondarySystemBackground

        /**
         Text color of labels

         Default value — `.secondaryLabel`
         */
        public var textColor: UIColor = .secondaryLabel

        /**
         Text font of labels

         Default value — `.systemFont(ofSize: 10, weight: .bold)`
         */
        public var textFont: UIFont = .systemFont(ofSize: 10, weight: .bold)

        /**
         Height of the view

         Default value — `28pt`
         */
        public var height: CGFloat = 28

        /**
         Corner radius of the view

         Default value — `8pt`
         */
        public var cornerRadius: CGFloat = 8

        /**
         Make week names uppercased

         Default value — `true`
         */
        public var uppercaseWeekName = true

    }
}
