import AppKit
import Darwin
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let powerSettings = PowerSettings()
    private let slowLaneManager = SlowLaneManager()
    private let brightnessManager = BrightnessManager()
    private let powerMonitor = PowerMonitor()
    private let fanMonitor = FanMonitor()
    private let temperatureMonitor = TemperatureMonitor()
    private let systemResourceMonitor = SystemResourceMonitor()
    private let networkMonitor = NetworkTelemetryMonitor()
    private let fanControlManager = FanControlManager()
    private let menuBarPreferences = MenuBarPreferences()
    private let languagePreferences = LanguagePreferences()
    private lazy var settingsPanelController = SettingsPanelController()
    private lazy var statusBarController = StatusBarController()
    private var isLidModeEnabled = false
    private var isLowPowerModeEnabled = false
    private var isFanManualEnabled = false
    private var isTransitioning = false
    private var isFanTransitioning = false
    private var isEnablingManualFan = false
    private var isTerminationPending = false
    private var deferredTermination = DeferredTerminationCoordinator()
    private var lidControlAvailable = false
    private var fanSpeedPercentage = 65
    private var fanPercentageAtManualEnable = 65
    private var hasAcknowledgedLowFanSpeed = false
    private var latestPowerReading: PowerReading?
    private var latestFanReading: FanReading?
    private var latestTemperatureReading: TemperatureReading?
    private var latestSystemResourceReading: SystemResourceReading?
    private var latestNetworkReading: NetworkTelemetryReading?
    private var hasReceivedFanSample = false
    private var window: NSWindow!
    private var mainControlView: MainControlView!
    private var lidModeSwitch: NSSwitch!
    private var lowPowerModeSwitch: NSSwitch!
    private var manualFanSwitch: NSSwitch!
    private var fanSpeedSlider: NSSlider!
    private var thermalTimer: Timer?
    private var slowLaneTimer: Timer?
    private let transitionQueue = DispatchQueue(label: "io.github.achengbatian.lidrunswitch.transition", qos: .userInitiated)
    private let fanControlQueue = DispatchQueue(label: "io.github.achengbatian.lidrunswitch.fan-control", qos: .userInitiated)
    private let slowLaneQueue = DispatchQueue(label: "io.github.achengbatian.lidrunswitch.slow-lane", qos: .utility)
    private var slowLaneCheckInProgress = false
    private var pendingFanUpdateWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(MainWindowBehavior.activationPolicy)
        let selectedLanguage: AppLanguage
        if let savedLanguage = languagePreferences.selectedLanguage {
            selectedLanguage = savedLanguage
        } else {
            selectedLanguage = LanguageSelectionController.chooseInitialLanguage()
            languagePreferences.selectedLanguage = selectedLanguage
        }
        L10n.use(selectedLanguage)
        buildWindow()
        lidControlAvailable = LidStateReader.current() != .unknown
        mainControlView.setLidControlAvailable(lidControlAvailable)
        MainWindowBehavior.show(window)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        configureStatusBar()
        configureSettings()
        brightnessManager.recoverIfNeeded()
        powerMonitor.onUpdate = { [weak self] reading in
            let statusText = reading?.statusText ?? "-- W"
            let detailText = reading?.combinedDetailText
                ?? L10n.text(
                    "电脑用电与充电输入：暂时无法读取",
                    "Mac power use and charging input are unavailable"
                )
            self?.latestPowerReading = reading
            self?.statusBarController.updatePower(statusText, detail: detailText)
            self?.mainControlView.updatePower(reading)
        }
        powerMonitor.start()
        fanMonitor.onUpdate = { [weak self] reading in
            guard let self else { return }
            self.hasReceivedFanSample = true
            self.latestFanReading = reading
            self.mainControlView.updateFans(reading)
            self.statusBarController.updateFans(reading)
            self.updateFanControls()
        }
        fanMonitor.start()
        temperatureMonitor.onUpdate = { [weak self] reading in
            guard let self else { return }
            self.latestTemperatureReading = reading
            self.mainControlView.updateTemperature(reading)
            self.statusBarController.updateTemperature(reading)
            self.refreshLidControlAvailability()
            self.handleTemperatureSafety(reading)
        }
        temperatureMonitor.start()
        systemResourceMonitor.onUpdate = { [weak self] reading in
            self?.latestSystemResourceReading = reading
            self?.mainControlView.updateSystemResources(reading)
            self?.statusBarController.updateSystemResources(reading)
        }
        systemResourceMonitor.start()
        networkMonitor.onUpdate = { [weak self] reading in
            self?.latestNetworkReading = reading
            self?.mainControlView.updateNetwork(reading)
            self?.statusBarController.updateNetwork(reading)
        }
        networkMonitor.start()
        updateModeControls()
        updateFanControls()
        updateStatusForModes()
        handleInterruptedSessionRecovery(powerSettings.recoverInterruptedSessionIfNeeded())
        handleInterruptedFanRecovery(fanControlManager.recoverInterruptedSessionIfNeeded())
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainWindowBehavior.terminatesAfterLastWindowClosed
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        MainWindowBehavior.handleClose(sender)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminationPending else {
            return .terminateCancel
        }
        if deferredTermination.requestIfBusy(isTransitioning || isFanTransitioning) {
            setStatus(
                L10n.text(
                    "当前操作完成后将安全退出...",
                    "LitRun! will quit after the current operation..."
                ),
                tone: .working,
                busy: true
            )
            return .terminateCancel
        }
        deferredTermination.clear()
        isTerminationPending = true
        isTransitioning = true
        isFanTransitioning = isFanManualEnabled
        setStatus(
            L10n.text("正在安全退出...", "Quitting safely..."),
            tone: .working,
            busy: true
        )
        updateModeControls()
        updateFanControls()
        stopThermalMonitor()
        stopSlowLaneMonitor()

        let shouldRestorePower = isLidModeEnabled
        let shouldRestoreFans = isFanManualEnabled
        transitionQueue.async { [weak self] in
            guard let self else { return }
            let fanResult: Result<Void, Error>
            if shouldRestoreFans {
                fanResult = Result { try self.fanControlManager.disable() }
            } else {
                fanResult = .success(())
            }
            let powerResult: Result<Void, Error>
            if shouldRestorePower {
                powerResult = Result { try self.powerSettings.disable() }
            } else {
                powerResult = .success(())
            }
            _ = self.slowLaneQueue.sync {
                self.slowLaneManager.restoreTouchedProcesses()
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isTerminationPending = false
                self.isTransitioning = false
                self.isFanTransitioning = false

                if case .success = powerResult {
                    self.isLidModeEnabled = false
                }
                if case .success = fanResult {
                    self.isFanManualEnabled = false
                }

                switch (powerResult, fanResult) {
                case (.success, .success):
                    self.isLowPowerModeEnabled = false
                    self.brightnessManager.stopAndRestore()
                    self.powerMonitor.stop()
                    self.fanMonitor.stop()
                    self.temperatureMonitor.stop()
                    self.systemResourceMonitor.stop()
                    self.networkMonitor.stop()
                    sender.reply(toApplicationShouldTerminate: true)
                case (.failure(let error), _), (_, .failure(let error)):
                    self.updateModeControls()
                    self.updateFanControls()
                    self.updateStatusForModes()
                    self.updateThermalMonitoring()
                    self.updateSlowLaneMonitoring()
                    self.showAlert(
                        title: L10n.text("恢复失败", "Restore Failed"),
                        message: error.localizedDescription
                    )
                    sender.reply(toApplicationShouldTerminate: false)
                }
            }
        }
        return .terminateLater
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 456, height: 272),
            styleMask: MainWindowBehavior.windowStyleMask,
            backing: .buffered,
            defer: false
        )
        window.title = L10n.language.productName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.setContentSize(NSSize(width: 456, height: 272))
        window.minSize = NSSize(width: 456, height: 272)
        window.maxSize = NSSize(width: 456, height: 272)
        window.center()
        window.delegate = self

        mainControlView = MainControlView(frame: NSRect(x: 0, y: 0, width: 456, height: 272))
        mainControlView.autoresizingMask = [.width, .height]
        window.contentView = mainControlView

        lidModeSwitch = mainControlView.lidModeSwitch
        lowPowerModeSwitch = mainControlView.lowPowerModeSwitch
        manualFanSwitch = mainControlView.manualFanSwitch
        fanSpeedSlider = mainControlView.fanSpeedSlider

        lidModeSwitch.target = self
        lidModeSwitch.action = #selector(toggleLidMode)
        lowPowerModeSwitch.target = self
        lowPowerModeSwitch.action = #selector(toggleLowPowerMode)
        manualFanSwitch.target = self
        manualFanSwitch.action = #selector(toggleManualFan)
        fanSpeedSlider.target = self
        fanSpeedSlider.action = #selector(fanSpeedChanged)
        mainControlView.settingsButton.target = self
        mainControlView.settingsButton.action = #selector(showSettings)
    }

    private func configureStatusBar() {
        statusBarController.onShowWindow = { [weak self] in
            self?.showMainWindow()
        }
        statusBarController.onToggleLidMode = { [weak self] in
            self?.toggleLidMode()
        }
        statusBarController.onToggleLowPowerMode = { [weak self] in
            self?.toggleLowPowerMode()
        }
        statusBarController.onRemovePrivilegedComponents = { [weak self] in
            self?.removePrivilegedComponents()
        }
        statusBarController.onQuit = {
            NSApp.terminate(nil)
        }
        statusBarController.updateSelection(menuBarPreferences.selection)
        statusBarController.updateModes(lidModeEnabled: false, lowPowerModeEnabled: false)
        statusBarController.applyLanguage()
    }

    private func configureSettings() {
        settingsPanelController.setSelection(menuBarPreferences.selection)
        settingsPanelController.setLanguage(L10n.language)
        settingsPanelController.onSelectionChange = { [weak self] selection in
            guard let self else { return }
            self.menuBarPreferences.selection = selection
            self.statusBarController.updateSelection(selection)
        }
        settingsPanelController.onLanguageChange = { [weak self] language in
            self?.changeLanguage(to: language)
        }
    }

    @objc private func showSettings() {
        settingsPanelController.toggle(from: mainControlView.settingsButton)
    }

    private func showMainWindow() {
        MainWindowBehavior.show(window)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func changeLanguage(to language: AppLanguage) {
        guard language != L10n.language else { return }
        L10n.use(language)
        languagePreferences.selectedLanguage = language
        window.title = language.productName
        mainControlView.applyLanguage()
        settingsPanelController.setLanguage(language)
        statusBarController.applyLanguage()
        mainControlView.updatePower(latestPowerReading)
        mainControlView.updateSystemResources(latestSystemResourceReading)
        mainControlView.updateNetwork(latestNetworkReading)
        statusBarController.updateSystemResources(latestSystemResourceReading)
        statusBarController.updateNetwork(latestNetworkReading)
        if let latestTemperatureReading {
            mainControlView.updateTemperature(latestTemperatureReading)
            statusBarController.updateTemperature(latestTemperatureReading)
        }
        mainControlView.updateFans(latestFanReading)
        statusBarController.updateFans(latestFanReading)
        if let latestPowerReading {
            statusBarController.updatePower(
                latestPowerReading.statusText,
                detail: latestPowerReading.combinedDetailText
            )
        } else {
            statusBarController.updatePower(
                "-- W",
                detail: L10n.text(
                    "电脑用电与充电输入：暂时无法读取",
                    "Mac power use and charging input are unavailable"
                )
            )
        }
        updateFanControls()
        if isTransitioning || isFanTransitioning || isTerminationPending {
            setStatus(
                L10n.text("正在处理...", "Working..."),
                tone: .working,
                busy: true
            )
        } else {
            updateStatusForModes()
        }
    }

    private func enableLidMode() {
        guard !isLidModeEnabled, !isTransitioning else { return }
        isTransitioning = true
        setStatus(
            L10n.text("正在开启合盖运行...", "Enabling lid-closed running..."),
            tone: .working,
            busy: true
        )
        updateModeControls()
        lidModeSwitch.state = .on
        mainControlView.updateModeAppearance(
            lidModeEnabled: true,
            lowPowerModeEnabled: isLowPowerModeEnabled
        )

        transitionQueue.async { [weak self] in
            guard let self else { return }
            let result = Result { try self.powerSettings.enable() }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isTransitioning = false
                switch result {
                case .success:
                    self.isLidModeEnabled = true
                    self.brightnessManager.start()
                    self.updateModeControls()
                    self.updateStatusForModes()
                    self.updateThermalMonitoring()
                    self.updateSlowLaneMonitoring()
                case .failure(let error):
                    self.isLidModeEnabled = false
                    self.setStatus(
                        L10n.text(
                            "合盖运行未开启",
                            "Lid-closed running was not enabled"
                        ),
                        tone: .warning
                    )
                    self.updateModeControls()
                    self.showAlert(
                        title: L10n.text("开启失败", "Could Not Enable"),
                        message: error.localizedDescription
                    )
                }
                self.continuePendingTerminationIfNeeded()
            }
        }
    }

    @objc private func thermalStateDidChange() {
        handleThermalStateChange()
    }

    @objc private func toggleLidMode() {
        guard !isTransitioning,
              lidControlAvailable || isLidModeEnabled
        else {
            return
        }
        if isLidModeEnabled {
            disableLidMode()
        } else {
            enableLidMode()
        }
    }

    @objc private func toggleLowPowerMode() {
        guard !isTransitioning else { return }
        setLowPowerMode(!isLowPowerModeEnabled)
    }

    @objc private func toggleManualFan() {
        guard !isFanTransitioning, !isTerminationPending else { return }
        if isFanManualEnabled {
            disableManualFan()
        } else {
            enableManualFan()
        }
    }

    @objc private func fanSpeedChanged() {
        guard !isTerminationPending,
              !isFanTransitioning || isEnablingManualFan
        else {
            return
        }
        let requestedPercentage = Int(fanSpeedSlider.doubleValue.rounded())
        guard acknowledgeLowFanSpeedIfNeeded(requestedPercentage) else {
            mainControlView.updateFanAppearance(
                manualEnabled: isFanManualEnabled,
                percentage: fanSpeedPercentage
            )
            return
        }

        fanSpeedPercentage = requestedPercentage
        mainControlView.updateFanAppearance(
            manualEnabled: isFanManualEnabled,
            percentage: fanSpeedPercentage
        )
        if isFanManualEnabled {
            scheduleManualFanTargetUpdate()
        } else if !isEnablingManualFan {
            enableManualFan()
        }
    }

    private func scheduleManualFanTargetUpdate() {
        pendingFanUpdateWorkItem?.cancel()
        let requestedPercentage = fanSpeedPercentage
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isFanManualEnabled,
                  !self.isFanTransitioning,
                  self.fanSpeedPercentage == requestedPercentage
            else {
                return
            }
            self.pendingFanUpdateWorkItem = nil
            self.updateManualFanTarget()
        }
        pendingFanUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func enableManualFan() {
        guard acknowledgeLowFanSpeedIfNeeded(fanSpeedPercentage) else {
            manualFanSwitch.state = .off
            return
        }
        guard let targets = fanTargetsForCurrentReading() else {
            manualFanSwitch.state = .off
            showAlert(
                title: L10n.text("暂时无法开启", "Not Ready Yet"),
                message: L10n.text(
                    "还没有读到风扇上限，请稍后再试。",
                    "Fan limits have not been read yet. Try again shortly."
                )
            )
            return
        }

        isFanTransitioning = true
        isEnablingManualFan = true
        fanPercentageAtManualEnable = fanSpeedPercentage
        manualFanSwitch.state = .on
        setStatus(
            L10n.text("正在开启手动风扇...", "Enabling manual fans..."),
            tone: .working,
            busy: true
        )
        updateFanControls()

        fanControlQueue.async { [weak self] in
            guard let self else { return }
            let result = Result { try self.fanControlManager.enable(targets: targets) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let shouldApplyLatestPercentage =
                    self.fanSpeedPercentage != self.fanPercentageAtManualEnable
                self.isFanTransitioning = false
                self.isEnablingManualFan = false
                switch result {
                case .success:
                    self.isFanManualEnabled = true
                    self.updateFanControls()
                    self.updateStatusForModes()
                    self.updateThermalMonitoring()
                    if shouldApplyLatestPercentage {
                        self.scheduleManualFanTargetUpdate()
                    }
                case .failure(let error):
                    self.isFanManualEnabled = false
                    self.hasAcknowledgedLowFanSpeed = false
                    self.updateFanControls()
                    self.updateStatusForModes()
                    self.showAlert(
                        title: L10n.text(
                            "手动风扇未开启",
                            "Manual Fans Were Not Enabled"
                        ),
                        message: error.localizedDescription
                    )
                }
                self.continuePendingTerminationIfNeeded()
            }
        }
    }

    private func updateManualFanTarget() {
        pendingFanUpdateWorkItem?.cancel()
        pendingFanUpdateWorkItem = nil
        guard let targets = fanTargetsForCurrentReading() else { return }
        isFanTransitioning = true
        setStatus(
            L10n.text("正在调整风扇...", "Adjusting fans..."),
            tone: .working,
            busy: true
        )
        updateFanControls()

        fanControlQueue.async { [weak self] in
            guard let self else { return }
            let result = Result { try self.fanControlManager.update(targets: targets) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFanTransitioning = false
                switch result {
                case .success:
                    self.updateFanControls()
                    self.updateStatusForModes()
                case .failure(let error):
                    self.isFanManualEnabled = false
                    self.hasAcknowledgedLowFanSpeed = false
                    self.updateFanControls()
                    self.updateStatusForModes()
                    self.updateThermalMonitoring()
                    self.showAlert(
                        title: L10n.text("调整失败", "Adjustment Failed"),
                        message: error.localizedDescription
                    )
                }
                self.continuePendingTerminationIfNeeded()
            }
        }
    }

    private func disableManualFan(completion: ((Bool) -> Void)? = nil) {
        pendingFanUpdateWorkItem?.cancel()
        pendingFanUpdateWorkItem = nil
        guard isFanManualEnabled, !isFanTransitioning else {
            completion?(!isFanManualEnabled)
            return
        }
        isFanTransitioning = true
        manualFanSwitch.state = .off
        setStatus(
            L10n.text(
                "正在恢复自动风扇...",
                "Restoring automatic fan control..."
            ),
            tone: .working,
            busy: true
        )
        updateFanControls()

        fanControlQueue.async { [weak self] in
            guard let self else { return }
            let result = Result { try self.fanControlManager.disable() }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFanTransitioning = false
                switch result {
                case .success:
                    self.isFanManualEnabled = false
                    self.hasAcknowledgedLowFanSpeed = false
                    self.updateFanControls()
                    self.updateStatusForModes()
                    self.updateThermalMonitoring()
                    completion?(true)
                case .failure(let error):
                    self.updateFanControls()
                    self.updateStatusForModes()
                    self.showAlert(
                        title: L10n.text(
                            "自动风扇恢复失败",
                            "Automatic Fan Restore Failed"
                        ),
                        message: error.localizedDescription
                    )
                    completion?(false)
                }
                self.continuePendingTerminationIfNeeded()
            }
        }
    }

    private func fanTargetsForCurrentReading() -> [Int]? {
        guard let reading = latestFanReading,
              reading.manualControlSupported,
              !reading.fans.isEmpty
        else {
            return nil
        }
        let fans = reading.fans
        let targets = fans.compactMap { fan -> Int? in
            guard let maximum = fan.maximumRPM, maximum > 0 else { return nil }
            return FanControlPolicy.targetRPM(
                maximumRPM: maximum,
                percentage: fanSpeedPercentage
            )
        }
        return targets.count == fans.count ? targets : nil
    }

    private func acknowledgeLowFanSpeedIfNeeded(_ percentage: Int) -> Bool {
        guard FanControlPolicy.requiresLowSpeedWarning(percentage),
              !hasAcknowledgedLowFanSpeed
        else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = percentage == 0
            ? L10n.text("确认关闭所有风扇？", "Turn Off All Fans?")
            : L10n.text("确认使用低风扇转速？", "Use a Low Fan Speed?")
        alert.informativeText = L10n.text(
            """
            低于 50% 会覆盖 macOS 自动温控；0% 会要求所有可控风扇停止。\
            仅在开盖、通风、轻负载时短时使用。芯片达到 99°C，\
            或 macOS 报告升温或严重过热时，App 会恢复自动温控。
            """,
            """
            Below 50% overrides macOS automatic fan control; 0% requests all \
            controllable fans to stop. Use only briefly with the lid open, good \
            airflow, and a light load. Automatic control returns at 99°C or when \
            macOS reports elevated or serious heat.
            """
        )
        alert.alertStyle = .critical
        alert.addButton(
            withTitle: percentage == 0
                ? L10n.text("关闭风扇", "Turn Off Fans")
                : L10n.text("继续低速", "Continue")
        )
        alert.addButton(withTitle: L10n.text("取消", "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }
        hasAcknowledgedLowFanSpeed = true
        return true
    }

    private func disableLidMode(completion: ((Bool) -> Void)? = nil) {
        guard isLidModeEnabled, !isTransitioning else {
            completion?(!isLidModeEnabled)
            return
        }
        isTransitioning = true
        setStatus(
            L10n.text(
                "正在关闭合盖运行...",
                "Disabling lid-closed running..."
            ),
            tone: .working,
            busy: true
        )
        updateModeControls()
        lidModeSwitch.state = .off
        mainControlView.updateModeAppearance(
            lidModeEnabled: false,
            lowPowerModeEnabled: isLowPowerModeEnabled
        )

        transitionQueue.async { [weak self] in
            guard let self else { return }
            let result = Result { try self.powerSettings.disable() }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isTransitioning = false

                switch result {
                case .success:
                    self.brightnessManager.stopAndRestore()
                    self.isLidModeEnabled = false
                    self.updateModeControls()
                    self.updateStatusForModes()
                    self.updateThermalMonitoring()
                    self.updateSlowLaneMonitoring()
                    completion?(true)
                case .failure(let error):
                    self.setStatus(
                        L10n.text(
                            "恢复失败，App 已保持打开。",
                            "Restore failed. LitRun! remains open."
                        ),
                        tone: .warning
                    )
                    self.updateThermalMonitoring()
                    self.updateModeControls()
                    self.showAlert(
                        title: L10n.text("恢复失败", "Restore Failed"),
                        message: error.localizedDescription
                    )
                    completion?(false)
                }
                self.continuePendingTerminationIfNeeded()
            }
        }
    }

    private func setLowPowerMode(_ enabled: Bool) {
        guard enabled != isLowPowerModeEnabled else { return }
        isLowPowerModeEnabled = enabled
        updateModeControls()
        updateStatusForModes()
        updateSlowLaneMonitoring()
    }

    private func updateModeControls() {
        lidModeSwitch.state = isLidModeEnabled ? .on : .off
        lowPowerModeSwitch.state = isLowPowerModeEnabled ? .on : .off
        let lidControlEnabled = !isTransitioning
            && (lidControlAvailable || isLidModeEnabled)
        let lowPowerControlEnabled = !isTransitioning
        lidModeSwitch.isEnabled = lidControlEnabled
        lowPowerModeSwitch.isEnabled = !isTransitioning
        mainControlView.updateModeAppearance(
            lidModeEnabled: isLidModeEnabled,
            lowPowerModeEnabled: isLowPowerModeEnabled
        )
        mainControlView.setModeControlsEnabled(
            lidEnabled: lidControlEnabled,
            lowPowerEnabled: lowPowerControlEnabled
        )
        statusBarController.updateModes(
            lidModeEnabled: isLidModeEnabled,
            lowPowerModeEnabled: isLowPowerModeEnabled,
            lidControlEnabled: lidControlEnabled,
            lowPowerControlEnabled: lowPowerControlEnabled
        )
    }

    private func refreshLidControlAvailability() {
        guard !lidControlAvailable, LidStateReader.current() != .unknown else {
            return
        }
        lidControlAvailable = true
        mainControlView.setLidControlAvailable(true)
        updateModeControls()
    }

    private func updateFanControls() {
        manualFanSwitch.state = isFanManualEnabled ? .on : .off
        statusBarController.updateFanMode(manual: isFanManualEnabled)
        let transitionAllowsSwitch = !isFanTransitioning && !isTerminationPending
        let transitionAllowsSlider =
            (!isFanTransitioning || isEnablingManualFan) && !isTerminationPending
        let supportsManualControl = latestFanReading?.manualControlSupported == true
        let switchEnabled = transitionAllowsSwitch
            && (supportsManualControl || isFanManualEnabled)
        let sliderEnabled = transitionAllowsSlider && supportsManualControl
        let availabilityText: String?
        if isFanManualEnabled {
            availabilityText = nil
        } else if !hasReceivedFanSample {
            availabilityText = L10n.text("检测中", "Detecting")
        } else if latestFanReading == nil {
            availabilityText = L10n.text("不可用", "Unavailable")
        } else if !supportsManualControl {
            availabilityText = L10n.text("只读", "Read only")
        } else {
            availabilityText = nil
        }
        mainControlView.setFanControlsEnabled(
            switchEnabled,
            sliderEnabled: sliderEnabled,
            availabilityText: availabilityText
        )
        mainControlView.updateFanAppearance(
            manualEnabled: isFanManualEnabled,
            percentage: fanSpeedPercentage
        )
    }

    private func updateStatusForModes() {
        let modeText: String
        switch (isLidModeEnabled, isLowPowerModeEnabled) {
        case (false, false):
            modeText = isFanManualEnabled
                ? L10n.text("手动风扇运行中", "Manual fans active")
                : L10n.text("待机", "Standby")
        case (true, false):
            modeText = L10n.text("合盖运行中", "Lid mode active")
        case (false, true):
            modeText = L10n.text("低功耗运行中", "Low power active")
        case (true, true):
            modeText = L10n.text(
                "合盖低功耗运行中",
                "Lid and low power active"
            )
        }

        if isFanManualEnabled, isLidModeEnabled || isLowPowerModeEnabled {
            setStatus(
                L10n.format(
                    "%@ · 手动风扇",
                    "%@ · Manual fans",
                    modeText
                ),
                tone: .active
            )
        } else {
            let standbyText = L10n.text("待机", "Standby")
            setStatus(modeText, tone: modeText == standbyText ? .idle : .active)
        }
    }

    private func setStatus(
        _ text: String,
        tone: MainControlView.StatusTone,
        busy: Bool = false
    ) {
        mainControlView.setStatus(text, tone: tone, busy: busy)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func continuePendingTerminationIfNeeded() {
        guard deferredTermination.consumeIfReady(
            isBusy: isTransitioning || isFanTransitioning,
            isTerminationPending: isTerminationPending
        ) else {
            return
        }
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    private func handleInterruptedSessionRecovery(_ recovery: InterruptedSessionRecovery) {
        switch recovery {
        case .none:
            break
        case .recovered:
            setStatus(
                L10n.text("已恢复上次会话", "Previous session restored"),
                tone: .active
            )
        case .needsAttention(let message):
            setStatus(L10n.text("需要恢复", "Restore needed"), tone: .warning)
            showAlert(
                title: L10n.text("需要恢复", "Restore Needed"),
                message: message
            )
        }
    }

    private func handleInterruptedFanRecovery(_ recovery: InterruptedFanRecovery) {
        switch recovery {
        case .none:
            break
        case .recovered:
            setStatus(
                L10n.text(
                    "风扇已恢复自动温控",
                    "Automatic fan control restored"
                ),
                tone: .active
            )
        case .needsAttention(let message):
            setStatus(
                L10n.text("风扇需要恢复", "Fan restore needed"),
                tone: .warning
            )
            showAlert(
                title: L10n.text("风扇需要恢复", "Fan Restore Needed"),
                message: message
            )
        }
    }

    @objc private func removePrivilegedComponents() {
        guard !isTransitioning, !isFanTransitioning else { return }
        guard !isLidModeEnabled, !isFanManualEnabled else {
            showAlert(
                title: L10n.text(
                    "请先关闭正在运行的功能",
                    "Turn Off Active Features First"
                ),
                message: L10n.text(
                    "关闭合盖运行和手动风扇后，才能移除管理员组件。",
                    "Turn off lid-closed running and manual fans before removing privileged components."
                )
            )
            return
        }

        let confirmation = NSAlert()
        confirmation.messageText = L10n.text(
            "移除管理员组件？",
            "Remove Privileged Components?"
        )
        confirmation.informativeText = L10n.text(
            "以后再次开启合盖运行时，需要重新输入一次管理员密码。",
            "The administrator password will be required again the next time lid-closed running is enabled."
        )
        confirmation.alertStyle = .warning
        confirmation.addButton(withTitle: L10n.text("移除", "Remove"))
        confirmation.addButton(withTitle: L10n.text("取消", "Cancel"))
        guard confirmation.runModal() == .alertFirstButtonReturn else { return }

        do {
            try powerSettings.removePrivilegedComponents()
            setStatus(
                L10n.text(
                    "管理员组件已移除",
                    "Privileged components removed"
                ),
                tone: .active
            )
        } catch {
            showAlert(
                title: L10n.text("移除失败", "Removal Failed"),
                message: error.localizedDescription
            )
        }
    }

    private func startThermalMonitor() {
        stopThermalMonitor()
        thermalTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.handleThermalStateChange()
        }
        handleThermalStateChange()
    }

    private func stopThermalMonitor() {
        thermalTimer?.invalidate()
        thermalTimer = nil
    }

    private func updateThermalMonitoring() {
        if isLidModeEnabled || isFanManualEnabled {
            startThermalMonitor()
        } else {
            stopThermalMonitor()
        }
    }

    private func startSlowLaneMonitor() {
        stopSlowLaneMonitor()
        slowLaneTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.scheduleSlowLaneCheck()
        }
        scheduleSlowLaneCheck()
    }

    private func stopSlowLaneMonitor() {
        slowLaneTimer?.invalidate()
        slowLaneTimer = nil
    }

    private func updateSlowLaneMonitoring() {
        stopSlowLaneMonitor()

        if ModePolicy.shouldRunSlowLane(lowPowerModeEnabled: isLowPowerModeEnabled) {
            startSlowLaneMonitor()
        } else {
            slowLaneQueue.async { [weak self] in
                self?.slowLaneManager.restoreTouchedProcesses()
            }
        }
    }

    private func scheduleSlowLaneCheck() {
        guard ModePolicy.shouldRunSlowLane(lowPowerModeEnabled: isLowPowerModeEnabled),
              !slowLaneCheckInProgress
        else { return }
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let frontmostPID = frontmostApplication?.processIdentifier
        let protectedPIDs = Set([frontmostPID].compactMap { $0 })
        let protectedCommandPrefixes = [
            frontmostApplication?.bundleURL?.path
        ].compactMap { $0 }
        let reliablePowerWatts = latestPowerReading.flatMap { reading in
            reading.source == .adapterInput ? nil : reading.watts
        }
        let pauseSeconds = LowPowerSchedulingPolicy.pauseSeconds(
            powerWatts: reliablePowerWatts,
            chipCelsius: latestTemperatureReading?.celsius,
            thermalState: latestTemperatureReading?.thermalState
                ?? ProcessInfo.processInfo.thermalState
        )
        slowLaneCheckInProgress = true

        slowLaneQueue.async { [weak self] in
            guard let self else { return }
            _ = self.slowLaneManager.apply(
                protectedPIDs: protectedPIDs,
                protectedCommandPrefixes: protectedCommandPrefixes,
                pauseSeconds: pauseSeconds
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.slowLaneCheckInProgress = false
            }
        }
    }

    private func handleThermalStateChange() {
        guard isLidModeEnabled || isFanManualEnabled else { return }

        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .fair,
           isFanManualEnabled,
           FanControlPolicy.requiresLowSpeedWarning(fanSpeedPercentage),
           !isFanTransitioning {
            setStatus(
                L10n.text(
                    "温度开始升高，正在恢复自动风扇。",
                    "Temperature is rising. Restoring automatic fans."
                ),
                tone: .warning,
                busy: true
            )
            disableManualFan { [weak self] succeeded in
                if succeeded {
                    self?.setStatus(
                        L10n.text(
                            "温度开始升高，风扇已恢复自动温控。",
                            "Temperature rose. Automatic fan control was restored."
                        ),
                        tone: .warning
                    )
                }
            }
            return
        }

        switch thermalState {
        case .serious, .critical:
            setStatus(
                L10n.text(
                    "温度升高，正在恢复系统保护。",
                    "Temperature is high. Restoring system protection."
                ),
                tone: .warning,
                busy: true
            )
            if isFanManualEnabled, !isFanTransitioning {
                disableManualFan { [weak self] succeeded in
                    if succeeded {
                        self?.setStatus(
                            L10n.text(
                                "温度升高，风扇已恢复自动温控。",
                                "Temperature rose. Automatic fan control was restored."
                            ),
                            tone: .warning
                        )
                    }
                }
            }
            if isLidModeEnabled, !isTransitioning {
                disableLidMode { [weak self] succeeded in
                    if succeeded {
                        self?.setStatus(
                            L10n.text(
                                "温度升高，合盖运行已自动关闭。",
                                "Temperature rose. Lid-closed running was turned off."
                            ),
                            tone: .warning
                        )
                    }
                }
            }
        case .nominal, .fair:
            break
        @unknown default:
            break
        }
    }

    private func handleTemperatureSafety(_ reading: TemperatureReading) {
        guard isFanManualEnabled,
              !isFanTransitioning,
              TemperatureSafetyPolicy.shouldRestoreAutomaticFans(
                  reading: reading,
                  fanPercentage: fanSpeedPercentage
              )
        else {
            return
        }

        setStatus(
            L10n.text(
                "温度升高，正在恢复自动风扇。",
                "Temperature is high. Restoring automatic fans."
            ),
            tone: .warning,
            busy: true
        )
        disableManualFan { [weak self] succeeded in
            if succeeded {
                self?.setStatus(
                    L10n.text(
                        "温度升高，风扇已恢复自动温控。",
                        "Temperature rose. Automatic fan control was restored."
                    ),
                    tone: .warning
                )
            }
        }
    }
}

if BrightnessManager.handleRecoveryCommandIfNeeded() {
    Darwin.exit(EXIT_SUCCESS)
}
let app = NSApplication.shared
if SingleInstanceGuard.activateExistingInstance() {
    Darwin.exit(EXIT_SUCCESS)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
