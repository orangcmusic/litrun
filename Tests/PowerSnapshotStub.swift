struct PowerSnapshot {
    let sleepDisabled: String
    let batterySleep: String
    let acSleep: String

    var restoreArguments: [String] {
        [
            "restore",
            sleepDisabled,
            batterySleep,
            acSleep
        ]
    }
}
