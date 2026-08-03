import AppKit

final class SettingsPanelController: NSObject {
    var onSelectionChange: ((MenuBarSelection) -> Void)?
    var onLanguageChange: ((AppLanguage) -> Void)?

    private let popover = NSPopover()
    private let titleLabel = NSTextField(labelWithString: "")
    private let languageLabel = NSTextField(labelWithString: "")
    private lazy var languageControl = NSSegmentedControl(
        labels: ["中文", "English"],
        trackingMode: .selectOne,
        target: self,
        action: #selector(languageChanged(_:))
    )
    private var selection = MenuBarSelection.defaultSelection
    private var language = AppLanguage.simplifiedChinese
    private var checkboxes: [MenuBarMetric: NSButton] = [:]

    override init() {
        super.init()
        buildInterface()
    }

    func setSelection(_ selection: MenuBarSelection) {
        self.selection = selection
        for metric in MenuBarMetric.allCases {
            checkboxes[metric]?.state = selection.contains(metric) ? .on : .off
        }
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        languageControl.selectedSegment = language.segmentIndex
        applyLanguage()
    }

    func toggle(from button: NSButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    var selectedMetricsForTesting: [MenuBarMetric] {
        selection.orderedMetrics
    }

    var selectedLanguageForTesting: AppLanguage {
        language
    }

    func selectLanguageForTesting(_ language: AppLanguage) {
        languageControl.selectedSegment = language.segmentIndex
        languageChanged(languageControl)
    }

    var contentViewForTesting: NSView? {
        popover.contentViewController?.view
    }

    private func buildInterface() {
        let controller = NSViewController()
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 236))

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7

        for (index, metric) in MenuBarMetric.allCases.enumerated() {
            let checkbox = NSButton(
                checkboxWithTitle: metric.title,
                target: self,
                action: #selector(selectionChanged(_:))
            )
            checkbox.controlSize = .regular
            checkbox.font = .systemFont(ofSize: 13, weight: .regular)
            checkbox.tag = index
            checkbox.state = .on
            checkbox.setAccessibilityLabel(
                L10n.format("状态栏显示%@", "Show %@ in menu bar", metric.title)
            )
            checkboxes[metric] = checkbox
            stack.addArrangedSubview(checkbox)
        }

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        languageLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        languageControl.translatesAutoresizingMaskIntoConstraints = false
        languageControl.controlSize = .small
        languageControl.selectedSegment = language.segmentIndex

        contentView.addSubview(titleLabel)
        contentView.addSubview(stack)
        contentView.addSubview(separator)
        contentView.addSubview(languageLabel)
        contentView.addSubview(languageControl)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 17),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -14),

            separator.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            languageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 17),
            languageLabel.centerYAnchor.constraint(equalTo: languageControl.centerYAnchor),

            languageControl.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 13),
            languageControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            languageControl.widthAnchor.constraint(equalToConstant: 126)
        ])

        controller.view = contentView
        controller.preferredContentSize = contentView.frame.size
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.animates = true
        applyLanguage()
    }

    @objc private func selectionChanged(_ sender: NSButton) {
        guard MenuBarMetric.allCases.indices.contains(sender.tag) else { return }
        let metric = MenuBarMetric.allCases[sender.tag]
        let next = selection.toggling(metric)
        setSelection(next)
        onSelectionChange?(next)
    }

    @objc private func languageChanged(_ sender: NSSegmentedControl) {
        guard let next = AppLanguage(segmentIndex: sender.selectedSegment) else {
            sender.selectedSegment = language.segmentIndex
            return
        }
        language = next
        onLanguageChange?(next)
    }

    private func applyLanguage() {
        titleLabel.stringValue = L10n.text("状态栏显示", "Menu bar")
        languageLabel.stringValue = L10n.text("语言", "Language")
        languageControl.setAccessibilityLabel(L10n.text("语言", "Language"))
        for metric in MenuBarMetric.allCases {
            checkboxes[metric]?.title = metric.title
            checkboxes[metric]?.setAccessibilityLabel(
                L10n.format("状态栏显示%@", "Show %@ in menu bar", metric.title)
            )
        }
    }
}
