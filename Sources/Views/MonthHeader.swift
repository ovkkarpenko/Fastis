//
//  FastisMonthHeader.swift
//  Fastis
//
//  Created by Ilya Kharlamov on 10.04.2020.
//  Copyright © 2020 DIGITAL RETAIL TECHNOLOGIES, S.L. All rights reserved.
//

import JTAppleCalendar
import UIKit

final class MonthHeader: JTACMonthReusableView {

    // MARK: - Outlets

    private lazy var weekView: WeekView = {
        let view = WeekView(calendar: .current, config: FastisConfig.default.weekView)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var monthLabel: UILabel = {
        let label = UILabel()
        label.text = "Month name"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Variables

    private var config: FastisConfig?
    
    internal var tapHandler: (() -> Void)?
    private lazy var monthFormatter = DateFormatter()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.configureSubviews()
        self.configureConstraints()
        self.applyConfig(FastisConfig.default.monthHeader, FastisConfig.default.weekView, calendar: .current)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.viewTapped))
        self.addGestureRecognizer(tapRecognizer)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configureSubviews() {
        self.addSubview(self.weekView)
        self.addSubview(self.monthLabel)
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            self.monthLabel.leftAnchor.constraint(equalTo: self.leftAnchor),
            self.monthLabel.rightAnchor.constraint(equalTo: self.rightAnchor),
            self.monthLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 6)
        ].compactMap({ $0 }))
        
        NSLayoutConstraint.activate([
            self.weekView.topAnchor.constraint(equalTo: self.monthLabel.bottomAnchor, constant: 16),
            self.weekView.leftAnchor.constraint(equalTo: self.leftAnchor),
            self.weekView.rightAnchor.constraint(equalTo: self.rightAnchor),
            self.weekView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    internal func configure(for date: Date) {
        self.monthLabel.text = self.monthFormatter.string(from: date).capitalizingFirstLetter()
    }

    // MARK: - Actions

    internal func applyConfig(_ config: FastisConfig.MonthHeader, _ weekConfig: FastisConfig.WeekView, calendar: Calendar) {
        self.weekView.configure(calendar: calendar, config: weekConfig)
        
        self.monthFormatter.calendar = calendar
        self.monthFormatter.dateFormat = config.monthFormat
        self.monthFormatter.locale = calendar.locale
        self.monthFormatter.timeZone = calendar.timeZone
        self.monthLabel.font = config.labelFont
        self.monthLabel.textColor = config.labelColor
        self.monthLabel.textAlignment = config.labelAlignment
    }

    @objc
    private func viewTapped() {
        self.tapHandler?()
    }

}

public extension FastisConfig {

    /**
     Month titles

     Configurable in FastisConfig.``FastisConfig/monthHeader-swift.property`` property
     */
    struct MonthHeader {

        /**
         Text alignment for month title label

         Default value — `.left`
         */
        public var labelAlignment: NSTextAlignment = .left

        /**
         Text color for month title label

         Default value — `.label`
         */
        public var labelColor: UIColor = .label

        /**
         Text font for month title label

         Default value — `.systemFont(ofSize: 17, weight: .semibold)`
         */
        public var labelFont: UIFont = .systemFont(ofSize: 17, weight: .semibold)

        /**
         Insets for month title label

         Default value — `UIEdgeInsets(top: 24, left: 8, bottom: 4, right: 16)`
         */
        public var insets = UIEdgeInsets(top: 24, left: 8, bottom: 4, right: 16)

        /**
         Format of displayed month value

         Default value — `"MMMM yyyy"`
         */
        public var monthFormat = "MMMM yyyy"

        /**
         Height of month view

         Default value — `48pt`
         */
        public var height = MonthSize(defaultSize: 70)
    }

}
