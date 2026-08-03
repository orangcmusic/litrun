struct DeferredTerminationCoordinator {
    private(set) var isRequested = false

    mutating func requestIfBusy(_ isBusy: Bool) -> Bool {
        guard isBusy else { return false }
        isRequested = true
        return true
    }

    mutating func clear() {
        isRequested = false
    }

    mutating func consumeIfReady(
        isBusy: Bool,
        isTerminationPending: Bool
    ) -> Bool {
        guard isRequested, !isBusy, !isTerminationPending else {
            return false
        }
        isRequested = false
        return true
    }
}
