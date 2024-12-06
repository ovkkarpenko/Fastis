//
//  FastisController.swift
//  Fastis
//
//  Created by Ilya Kharlamov on 10.04.2020.
//  Copyright © 2020 DIGITAL RETAIL TECHNOLOGIES, S.L. All rights reserved.
//

import JTAppleCalendar
import UIKit

/**
 Main controller of Fastis framework. Use it to create and present dade picker

 **Single and range modes**

 If you want to get a single date you have to use `Date` type:

 ```swift
 let fastisController = FastisController(mode: .single)
 fastisController.initialValue = Date()
 fastisController.closeOnSelectionImmediately = true
 fastisController.dismissHandler = { [weak self] action in
     switch action {
     case .done(let resultDate):
        print(resultDate) // resultDate is Date
     case .cancel:
        ...
     }
 }
 ```

 If you want to get a date range you have to use `FastisRange` type:

 ```swift
 let fastisController = FastisController(mode: .range)
 fastisController.initialValue = FastisRange(from: Date(), to: Date()) // or .from(Date(), to: Date())
 fastisController.dismissHandler = { [weak self] action in
     switch action {
     case .done(let resultRange):
        print(resultRange) // resultRange is FastisRange
     case .cancel:
        ...
     }
 }
 ```
 */
open class FastisController<Value: FastisValue>: UIViewController, JTACMonthViewDelegate, JTACMonthViewDataSource {

    open override var modalTransitionStyle: UIModalTransitionStyle {
        get {
            .coverVertical
        }

        set {}
    }

    open override var modalPresentationStyle: UIModalPresentationStyle {
        get {
            .overCurrentContext
        }

        set {}
    }
    
    // MARK: - Outlets

    
    
    private lazy var calendarView: JTACMonthView = {
        let monthView = JTACMonthView()
        monthView.translatesAutoresizingMaskIntoConstraints = false
        monthView.backgroundColor = self.appearance.backgroundColor
        monthView.ibCalendarDelegate = self
        monthView.ibCalendarDataSource = self
        monthView.minimumLineSpacing = 2
        monthView.minimumInteritemSpacing = 0
        monthView.showsVerticalScrollIndicator = false
        monthView.cellSize = 44
        monthView.allowsMultipleSelection = Value.mode == .range
        monthView.allowsRangedSelection = true
        monthView.rangeSelectionMode = .continuous
        monthView.contentInsetAdjustmentBehavior = .always
        return monthView
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bottomView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var resetButton: UIButton = {
        let button = UIButton()
        button.setTitle(config.controller.cancelButtonTitle, for: .normal)
        button.isEnabled = false
        button.addTarget(self, action: #selector(clear), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton()
        button.setTitle(config.controller.doneButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(done), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var bottomDoneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(config.controller.bottomDoneButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(bottomDone), for: .touchUpInside)
        button.addTarget(self, action: #selector(bottomDoneAll), for: .allEvents)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var chevronCompactDownImage: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = config.controller.chevronCompactDownColor
        imageView.image = config.controller.chevronCompactDownImage?.withRenderingMode(.alwaysTemplate)
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var shortcutContainerView: ShortcutContainerView<Value> = {
        let view = ShortcutContainerView<Value>(
            config: self.config.shortcutContainerView,
            itemConfig: self.config.shortcutItemView,
            shortcuts: self.shortcuts
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        if let value = self.value {
            view.selectedShortcut = self.shortcuts.first(where: {
                $0.isEqual(to: value, calendar: self.config.calendar)
            })
        }
        view.onSelect = { [weak self] selectedShortcut in
            guard let self else { return }
            let newValue = selectedShortcut.action(self.config.calendar)
            if !newValue.outOfRange(minDate: self.privateMinimumDate, maxDate: self.privateMaximumDate) {
                self.value = newValue
                self.selectValue(newValue, in: self.calendarView)
            }
        }
        return view
    }()
    
    private let panGestureRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer()

    // MARK: - Variables

    private let config: FastisConfig
    private var appearance: FastisConfig.Controller = FastisConfig.default.controller
    private let dayCellReuseIdentifier = "DayCellReuseIdentifier"
    private let monthHeaderReuseIdentifier = "MonthHeaderReuseIdentifier"
    private var viewConfigs: [IndexPath: DayCell.ViewConfig] = [:]
    private var privateMinimumDate: Date?
    private var privateMaximumDate: Date?
    private var privateAllowDateRangeChanges = true
    private var privateSelectMonthOnHeaderTap = false
    private var dayFormatter = DateFormatter()
    private var isDone = false
    private var privateCloseOnSelectionImmediately = false

    private var value: Value? {
        didSet {
            self.updateSelectedShortcut()
            self.resetButton.isEnabled = self.value != nil
        }
    }

    /**
     Shortcuts array

     Default value — `"[]"`

     You can use prepared shortcuts depending on the current mode.

     - For `.single` mode: `.today`, `.tomorrow`, `.yesterday`
     - For `.range` mode: `.today`, `.lastWeek`, `.lastMonth`

     Or you can create your own shortcuts:

     ```
     var customShortcut = FastisShortcut(name: "Today") {
         let now = Date()
         return FastisRange(from: now.startOfDay(), to: now.endOfDay())
     }
     ```
     */
    public var shortcuts: [FastisShortcut<Value>] = []

    /**
     Allow to choose `nil` date

     When `allowToChooseNilDate` is `true`:
     * "Done" button will be always enabled
     * You will be able to reset selection by you tapping on selected date again

     Default value — `"false"`
     */
    public var allowToChooseNilDate = false

    /**
     The block to execute after the dismissal finishes, return two variable `.done(FastisValue?)` and `.cancel`

     Default value — `"nil"`
     */
    public var dismissHandler: ((DismissAction) -> Void)?
    
    open var selectHandler: ((Bool) -> Void)?

    /**
     And initial value which will be selected by default

     Default value — `"nil"`
     */
    public var initialValue: Value?

    /**
     Minimal selection date. Dates less then current will be marked as unavailable

     Default value — `"nil"`
     */
    public var minimumDate: Date? {
        get {
            self.privateMinimumDate
        }
        set {
            self.privateMinimumDate = newValue?.startOfDay(in: self.config.calendar)
        }
    }

    /**
     Maximum selection date. Dates greater then current will be marked as unavailable

     Default value — `"nil"`
     */
    public var maximumDate: Date? {
        get {
            self.privateMaximumDate
        }
        set {
            self.privateMaximumDate = newValue?.endOfDay(in: self.config.calendar)
        }
    }

    public var didClose: (() -> Void)? = nil
    
    // MARK: - Lifecycle

    /// Initiate FastisController
    /// - Parameter config: Configuration parameters
    public init(config: FastisConfig = .default) {
        self.config = config
        self.appearance = config.controller
        self.dayFormatter.locale = config.calendar.locale
        self.dayFormatter.calendar = config.calendar
        self.dayFormatter.timeZone = config.calendar.timeZone
        self.dayFormatter.dateFormat = "d"
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.configureUI()
        self.configureSubviews()
        self.configureConstraints()
        self.configureInitialState()
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        showBottomSheet()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if self.isDone {
            self.dismissHandler?(.done(self.value))
        } else {
            self.dismissHandler?(.cancel)
        }

    }

    /**
     Present FastisController above current top view controller

     - Parameters:
        - viewController: view controller which will present FastisController
        - flag: Pass true to animate the presentation; otherwise, pass false.
        - completion: The block to execute after the presentation finishes. This block has no return value and takes no parameters. You may specify nil for this parameter.
     */
    public func present(above viewController: UIViewController, animated flag: Bool = true, completion: (() -> Void)? = nil) {
        let navVc = UINavigationController(rootViewController: self)
        navVc.modalPresentationStyle = .formSheet
        if viewController.preferredContentSize != .zero {
            navVc.preferredContentSize = viewController.preferredContentSize
        } else {
            navVc.preferredContentSize = CGSize(width: 445, height: 550)
        }

        viewController.present(navVc, animated: flag, completion: completion)
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if touches.first?.view == view {
            hideBottomSheet()
        }
    }
    
    // MARK: - Configuration

    private func configureUI() {
        self.view.backgroundColor = .clear
        self.navigationItem.largeTitleDisplayMode = .never
        
        self.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
        
        self.containerView.backgroundColor = self.appearance.backgroundColor
        self.bottomView.backgroundColor = self.appearance.backgroundColor
        self.containerView.layer.cornerRadius = 12
        self.containerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        self.view.addGestureRecognizer(panGestureRecognizer)
        
        self.headerView.backgroundColor = self.appearance.backgroundColor
        self.headerView.layer.cornerRadius = 12
        self.headerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]

        self.resetButton.titleLabel?.font = config.dayCell.dateLabelFont
        self.doneButton.titleLabel?.font = config.dayCell.dateLabelFont
        self.bottomDoneButton.titleLabel?.font = config.controller.bottomDoneButtonFont
        
        self.resetButton.setTitleColor(config.dayCell.selectedBackgroundColor, for: .normal)
        self.doneButton.setTitleColor(config.dayCell.selectedBackgroundColor, for: .normal)
        self.bottomDoneButton.setTitleColor(config.controller.bottomDoneButtonTextColor, for: .normal)
        
        self.resetButton.setTitleColor(config.dayCell.selectedBackgroundColor.withAlphaComponent(0.7), for: .highlighted)
        self.doneButton.setTitleColor(config.dayCell.selectedBackgroundColor.withAlphaComponent(0.7), for: .highlighted)
        
        self.resetButton.setTitleColor(config.dayCell.dateLabelUnavailableColor, for: .disabled)
        self.doneButton.setTitleColor(config.dayCell.dateLabelUnavailableColor, for: .disabled)
        self.bottomDoneButton.setTitleColor(config.controller.bottomDoneButtonTextColor, for: .disabled)
        
        self.bottomDoneButton.layer.cornerRadius = 12
        self.bottomDoneButton.backgroundColor = config.controller.bottomDoneButtonBackground
        self.bottomDoneButton.setTitleColor(config.dayCell.dateLabelUnavailableColor, for: .disabled)
        
        view.layoutIfNeeded()
        view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        bottomView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
    }

    private func configureSubviews() {
        self.containerView.addSubview(self.bottomView)
        
        self.calendarView.register(DayCell.self, forCellWithReuseIdentifier: self.dayCellReuseIdentifier)
        self.calendarView.register(
            MonthHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: self.monthHeaderReuseIdentifier
        )
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.headerView)
        self.headerView.addSubview(self.chevronCompactDownImage)
        
        if config.controller.bottomDoneButtonTitle == nil {
            self.containerView.addSubview(resetButton)
            self.containerView.addSubview(doneButton)
        } else {
            self.containerView.addSubview(bottomDoneButton)
        }
        
        self.containerView.addSubview(self.calendarView)
        if !self.shortcuts.isEmpty {
            self.containerView.addSubview(self.shortcutContainerView)
        }
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            self.bottomView.topAnchor.constraint(equalTo: self.containerView.bottomAnchor, constant: -150),
            self.bottomView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            self.bottomView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            self.bottomView.heightAnchor.constraint(equalToConstant: 300)
        ])
                                    
        if config.controller.onlyCurrentMonth {
            NSLayoutConstraint.activate([
                self.containerView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                self.containerView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                self.containerView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                self.containerView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 48),
                self.containerView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                self.containerView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                self.containerView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            ])
        }
        
        NSLayoutConstraint.activate([
            self.headerView.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            self.headerView.leftAnchor.constraint(equalTo: self.containerView.leftAnchor),
            self.headerView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor)
        ])
        
        NSLayoutConstraint.activate([
            self.chevronCompactDownImage.topAnchor.constraint(equalTo: self.headerView.topAnchor, constant: 12),
            self.chevronCompactDownImage.bottomAnchor.constraint(equalTo: self.headerView.bottomAnchor, constant: -4),
            self.chevronCompactDownImage.centerXAnchor.constraint(equalTo: self.containerView.centerXAnchor),
            self.chevronCompactDownImage.heightAnchor.constraint(equalToConstant: 10),
            self.chevronCompactDownImage.widthAnchor.constraint(equalToConstant: 36)
        ])
        
        if config.controller.bottomDoneButtonTitle == nil {
            NSLayoutConstraint.activate([
                self.resetButton.topAnchor.constraint(equalTo: self.headerView.bottomAnchor),
                self.resetButton.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 16),
                self.resetButton.heightAnchor.constraint(equalToConstant: 24)
            ])
            
            NSLayoutConstraint.activate([
                self.doneButton.topAnchor.constraint(equalTo: self.headerView.bottomAnchor),
                self.doneButton.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: -16),
                self.doneButton.heightAnchor.constraint(equalToConstant: 24)
            ])
            
            NSLayoutConstraint.activate([
                self.calendarView.topAnchor.constraint(equalTo: self.resetButton.bottomAnchor, constant: 14),
                self.calendarView.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 16),
                self.calendarView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: -16)
            ])
        } else {
            NSLayoutConstraint.activate([
                self.calendarView.topAnchor.constraint(equalTo: self.headerView.bottomAnchor),
                self.calendarView.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 16),
                self.calendarView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: -16)
            ])
            
            if config.controller.onlyCurrentMonth {
                NSLayoutConstraint.activate([
                    self.calendarView.heightAnchor.constraint(equalToConstant: 290)
                ])
            }
            
            NSLayoutConstraint.activate([
                self.bottomDoneButton.topAnchor.constraint(equalTo: self.calendarView.bottomAnchor, constant: 16),
                self.bottomDoneButton.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 16),
                self.bottomDoneButton.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: -16),
                self.bottomDoneButton.heightAnchor.constraint(equalToConstant: 52)
            ])
        }

        if !self.shortcuts.isEmpty {
            NSLayoutConstraint.activate([
                self.shortcutContainerView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor),
                self.shortcutContainerView.leftAnchor.constraint(equalTo: self.containerView.leftAnchor),
                self.shortcutContainerView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor)
            ])
        }
        if !self.shortcuts.isEmpty {
            NSLayoutConstraint.activate([
                self.calendarView.bottomAnchor.constraint(equalTo: self.shortcutContainerView.topAnchor)
            ])
        } else {
            if config.controller.bottomDoneButtonTitle == nil {
                NSLayoutConstraint.activate([
                    self.calendarView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    self.bottomDoneButton.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor, constant: -16)
                ])
            }
        }
    }

    private func configureInitialState() {
        self.value = self.initialValue
        if let date = self.value as? Date {
            self.calendarView.selectDates([date])
            self.calendarView.scrollToHeaderForDate(date)
        } else if let rangeValue = self.value as? FastisRange {
            self.selectRange(rangeValue, in: self.calendarView)
            self.calendarView.scrollToHeaderForDate(rangeValue.fromDate)
        } else {
            let nowDate = Date()
            let targetDate = self.privateMaximumDate ?? nowDate
            if targetDate < nowDate {
                self.calendarView.scrollToHeaderForDate(targetDate)
            } else {
                self.calendarView.scrollToHeaderForDate(Date())
            }
        }
    }

    private func configureCell(_ cell: JTACDayCell, forItemAt date: Date, cellState: CellState, indexPath: IndexPath) {
        guard let cell = cell as? DayCell else { return }
        if let cachedConfig = self.viewConfigs[indexPath] {
            cell.configure(for: cachedConfig)
        } else {
            var newConfig = DayCell.makeViewConfig(
                for: cellState,
                minimumDate: self.privateMinimumDate,
                maximumDate: self.privateMaximumDate,
                rangeValue: self.value as? FastisRange,
                calendar: self.config.calendar
            )

            if newConfig.dateLabelText != nil {
                newConfig.dateLabelText = self.dayFormatter.string(from: date)
            }

            if self.config.calendar.isDateInToday(date) {
                newConfig.isToday = true
            }

            newConfig.dateFont = newConfig.isSelectedViewHidden
                ? self.config.dayCell.dateLabelFont
                : self.config.dayCell.selectedDateLabelFont
            
            self.viewConfigs[indexPath] = newConfig
            cell.applyConfig(self.config)
            cell.configure(for: newConfig)
        }
    }

    // MARK: - Actions

    private func updateSelectedShortcut() {
        guard !self.shortcuts.isEmpty else { return }
        if let value = self.value {
            self.shortcutContainerView.selectedShortcut = self.shortcuts.first(where: {
                $0.isEqual(to: value, calendar: self.config.calendar)
            })
        } else {
            self.shortcutContainerView.selectedShortcut = nil
        }
    }

    @objc
    private func done() {
        self.isDone = true
        self.dismiss(animated: true)
    }
    
    @objc
    private func bottomDone() {
        doneButton.backgroundColor = config.controller.bottomDoneButtonBackground
        self.isDone = true
        self.dismiss(animated: true)
    }
    
    @objc
    private func bottomDoneAll() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.bottomDoneButton.backgroundColor = self.bottomDoneButton.isHighlighted
                ? self.config.controller.bottomDoneButtonHighlightedBackground
                : self.config.controller.bottomDoneButtonBackground
        }
    }
    
    @objc
    private func bottomDoneCalcel() {
        doneButton.backgroundColor = config.controller.bottomDoneButtonBackground
    }
    
    @objc
    private func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: view)

        switch gestureRecognizer.state {
        case .began:
            view.transform = .identity
            bottomView.transform = .identity

        case .changed:
            guard translation.y > 0 else { return }

            view.transform = CGAffineTransform(translationX: 0, y: translation.y)
            bottomView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            
        case .ended:
            if translation.y > 100 {
                hideBottomSheet()
            } else {
                showBottomSheet(damping: 0.6)
            }

        default:
            break
        }
    }

    private func hideBottomSheet() {
        didClose?()
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 1.9,
            options: [.curveEaseOut],
            animations: {
                self.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                self.bottomView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            }, completion: { _ in
                self.dismiss(animated: false)
            }
        )
    }
    
    private func showBottomSheet(damping: CGFloat = 0.8) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 1.9,
            options: [.curveEaseIn]
        ) {
            self.view.transform = .identity
            self.bottomView.transform = .identity
        }
    }

    private func selectValue(_ value: Value?, in calendar: JTACMonthView) {
        if let date = value as? Date {
            calendar.selectDates([date])
            resetButton.isEnabled = true
        } else if let range = value as? FastisRange {
            self.selectRange(range, in: calendar)
            resetButton.isEnabled = true
        } else {
            resetButton.isEnabled = false
        }
    }

    private func handleDateTap(in calendar: JTACMonthView, date: Date) {

        switch Value.mode {
        case .single:
            let oldDate = self.value as? Date
            if oldDate == date, self.allowToChooseNilDate {
                self.clear()
            } else {
                self.value = date as? Value
                self.selectValue(date as? Value, in: calendar)
            }

            if self.privateCloseOnSelectionImmediately, self.value != nil {
                self.done()
            }

        case .range:

            if self.allowToChooseNilDate,
               let oldValue = self.value as? FastisRange,
               date.isInSameDay(in: self.config.calendar, date: oldValue.fromDate),
               date.isInSameDay(in: self.config.calendar, date: oldValue.toDate)
            {
                self.clear()

            } else {

                let newValue: FastisRange = {
                    guard let oldValue = self.value as? FastisRange else {
                        return .from(date.startOfDay(in: self.config.calendar), to: date.endOfDay(in: self.config.calendar))
                    }

                    let dateRangeChangesDisabled = !self.privateAllowDateRangeChanges
                    let rangeSelected = !oldValue.fromDate.isInSameDay(in: self.config.calendar, date: oldValue.toDate)
                    if dateRangeChangesDisabled, rangeSelected {
                        return .from(date.startOfDay(in: self.config.calendar), to: date.endOfDay(in: self.config.calendar))
                    } else if date.isInSameDay(in: self.config.calendar, date: oldValue.fromDate) {
                        let newToDate = date.endOfDay(in: self.config.calendar)
                        return .from(oldValue.fromDate, to: newToDate)
                    } else if date.isInSameDay(in: self.config.calendar, date: oldValue.toDate) {
                        let newFromDate = date.startOfDay(in: self.config.calendar)
                        return .from(newFromDate, to: oldValue.toDate)
                    } else if date < oldValue.fromDate {
                        let newFromDate = date.startOfDay(in: self.config.calendar)
                        return .from(newFromDate, to: oldValue.toDate)
                    } else {
                        let newToDate = date.endOfDay(in: self.config.calendar)
                        return .from(oldValue.fromDate, to: newToDate)
                    }

                }()

                self.value = newValue as? Value
                self.selectValue(newValue as? Value, in: calendar)

            }

        }

    }

    private func selectRange(_ range: FastisRange, in calendar: JTACMonthView) {
        calendar.deselectAllDates(triggerSelectionDelegate: false)
        calendar.selectDates(
            from: range.fromDate,
            to: range.toDate,
            triggerSelectionDelegate: true,
            keepSelectionIfMultiSelectionAllowed: false
        )
        calendar.visibleDates { segment in
            UIView.performWithoutAnimation {
                calendar.reloadItems(at: (segment.outdates + segment.indates).map(\.indexPath))
            }
        }
    }

    @objc
    private func clear() {
        self.resetButton.isEnabled = false
        
        self.value = nil
        self.viewConfigs.removeAll()
        self.calendarView.deselectAllDates()
        self.calendarView.reloadData()
    }

    // MARK: - JTACMonthViewDelegate

    public func configureCalendar(_ calendar: JTACMonthView) -> ConfigurationParameters {

        var startDate = self.config.calendar.date(byAdding: .year, value: -99, to: Date())!
        var endDate = self.config.calendar.date(byAdding: .year, value: 99, to: Date())!
        
        if let maximumDate = self.privateMaximumDate,
           let endOfNextMonth = self.config.calendar.date(byAdding: .weekday, value: 2, to: maximumDate)?
            .endOfMonth(in: self.config.calendar) {
            if self.config.controller.onlyCurrentMonth {
                endDate = maximumDate
            } else {
                endDate = endOfNextMonth
            }
        }

        if let minimumDate = self.privateMinimumDate,
           let startOfPreviousMonth = self.config.calendar.date(byAdding: .weekday, value: -2, to: minimumDate)?
            .startOfMonth(in: self.config.calendar) {
            if self.config.controller.onlyCurrentMonth {
                startDate = minimumDate
            } else {
                startDate = startOfPreviousMonth
            }
        }

        return ConfigurationParameters(
            startDate: startDate,
            endDate: endDate,
            numberOfRows: 6,
            calendar: self.config.calendar,
            generateInDates: .forAllMonths,
            generateOutDates: .tillEndOfRow,
            firstDayOfWeek: nil,
            hasStrictBoundaries: true
        )
    }

    public func calendar(
        _ calendar: JTACMonthView,
        headerViewForDateRange range: (start: Date, end: Date),
        at indexPath: IndexPath
    ) -> JTACMonthReusableView {
        let header = calendar.dequeueReusableJTAppleSupplementaryView(
            withReuseIdentifier: self.monthHeaderReuseIdentifier,
            for: indexPath
        ) as! MonthHeader
        
        header.applyConfig(self.config.monthHeader, self.config.weekView, calendar: self.config.calendar)
        header.configure(for: range.start)
        
        if self.privateSelectMonthOnHeaderTap, Value.mode == .range {
            header.tapHandler = { [weak self, weak calendar] in
                guard let self, let calendar else { return }
                var fromDate = range.start.startOfMonth(in: self.config.calendar)
                var toDate = range.start.endOfMonth(in: self.config.calendar)
                if let minDate = self.minimumDate {
                    if toDate < minDate { return } else if fromDate < minDate {
                        fromDate = minDate.startOfDay(in: self.config.calendar)
                    }
                }
                if let maxDate = self.maximumDate {
                    if fromDate > maxDate { return } else if toDate > maxDate {
                        toDate = maxDate.endOfDay(in: self.config.calendar)
                    }
                }
                let newValue: FastisRange = .from(fromDate, to: toDate)
                self.value = newValue as? Value
                self.selectRange(newValue, in: calendar)
            }
        }
        return header
    }

    public func calendar(_ calendar: JTACMonthView, cellForItemAt date: Date, cellState: CellState, indexPath: IndexPath) -> JTACDayCell {
        let cell = calendar.dequeueReusableJTAppleCell(withReuseIdentifier: self.dayCellReuseIdentifier, for: indexPath)
        self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
        return cell
    }

    public func calendar(
        _ calendar: JTACMonthView,
        willDisplay cell: JTACDayCell,
        forItemAt date: Date,
        cellState: CellState,
        indexPath: IndexPath
    ) {
        self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
    }

    public func calendar(
        _ calendar: JTACMonthView,
        didSelectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) {
        if cellState.selectionType == .some(.userInitiated) {
            self.handleDateTap(in: calendar, date: date)
        } else if let cell {
            self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
        }
    }

    public func calendar(
        _ calendar: JTACMonthView,
        didDeselectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) {
        if cellState.selectionType == .some(.userInitiated), Value.mode == .range {
            self.handleDateTap(in: calendar, date: date)
        } else if let cell {
            self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
        }
    }

    public func calendar(
        _ calendar: JTACMonthView,
        shouldSelectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) -> Bool {
        self.viewConfigs.removeAll()
        return true
    }

    public func calendar(
        _ calendar: JTACMonthView,
        shouldDeselectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) -> Bool {
        self.viewConfigs.removeAll()
        return true
    }

    public func calendarSizeForMonths(_ calendar: JTACMonthView?) -> MonthSize? {
        self.config.monthHeader.height
    }

}

public extension FastisController where Value == FastisRange {

    /// Initiate FastisController
    /// - Parameters:
    ///   - mode: Choose `.range` or `.single` mode
    ///   - config: Custom configuration parameters. Default value is equal to `FastisConfig.default`
    convenience init(mode: FastisModeRange, config: FastisConfig = .default) {
        self.init(config: config)
        self.selectMonthOnHeaderTap = true
    }

    /**
     Set this variable to `true` if you want to allow select date ranges by tapping on months

     Default value — `"false"`
     */
    var selectMonthOnHeaderTap: Bool {
        get {
            self.privateSelectMonthOnHeaderTap
        }
        set {
            self.privateSelectMonthOnHeaderTap = newValue
        }
    }

    /**
     Allow date range changes

     Set this variable to `false` if you want to disable date range changes.
     Next tap after selecting range will start new range selection.

     Default value — `"true"`
     */
    var allowDateRangeChanges: Bool {
        get {
            self.privateAllowDateRangeChanges
        }
        set {
            self.privateAllowDateRangeChanges = newValue
        }
    }

}

public extension FastisController where Value == Date {

    /// Initiate FastisController
    /// - Parameters:
    ///   - mode: Choose .range or .single mode
    ///   - config: Custom configuration parameters. Default value is equal to `FastisConfig.default`
    convenience init(mode: FastisModeSingle, config: FastisConfig = .default) {
        self.init(config: config)
    }

    /**
     Set this variable to `true` if you want to hide view of the selected date and close the controller right after the date is selected.

     Default value — `"false"`
     */
    var closeOnSelectionImmediately: Bool {
        get {
            self.privateCloseOnSelectionImmediately
        }
        set {
            self.privateCloseOnSelectionImmediately = newValue
        }
    }

}

public extension FastisConfig {

    /**
     Configuration of base view controller (`cancelButtonTitle`, `doneButtonTitle`, etc.)

     Configurable in FastisConfig.``FastisConfig/controller-swift.property`` property
     */
    struct Controller {

        /**
         Cancel button title

         Default value — `"Cancel"`
         */
        public var cancelButtonTitle: String? = "Скинути"

        /**
         Done button title

         Default value — `"Done"`
         */
        public var doneButtonTitle: String? = "Готово"
        
        public var bottomDoneButtonTitle: String?
        public var bottomDoneButtonFont: UIFont?
        public var bottomDoneButtonTextColor: UIColor = .white
        public var bottomDoneButtonBackground: UIColor = .green
        public var bottomDoneButtonHighlightedBackground: UIColor = .green

        /**
         Controller's background color

         Default value — `.systemBackground`
         */
        public var backgroundColor: UIColor = .systemBackground

        /**
         Bar button items tint color

         Default value — `.systemBlue`
         */
        public var barButtonItemsColor: UIColor = .systemBlue
        
        public var chevronCompactDownColor: UIColor = .gray
        
        public var chevronCompactDownImage: UIImage?

        /**
         Custom cancel button in navigation bar

         Default value — `nil`
         */
        public var customCancelButton: UIBarButtonItem?

        /**
         Custom done button in navigation bar

         Default value — `nil`
         */
        public var customDoneButton: UIBarButtonItem?
        
        public var onlyCurrentMonth: Bool = false
    }
}

public extension FastisController {

    /**
     Parameter to return in the dismissHandler

     `.done(Value?)` - If a date is selected.
     `.cancel` - if controller closed without date selection
     */
    enum DismissAction {
        case done(Value?)
        case cancel
    }
}
