@main
enum DeferredTerminationCoordinatorSmoke {
    static func main() {
        var coordinator = DeferredTerminationCoordinator()
        precondition(!coordinator.requestIfBusy(false))
        precondition(!coordinator.isRequested)

        precondition(coordinator.requestIfBusy(true))
        precondition(coordinator.isRequested)
        precondition(!coordinator.consumeIfReady(
            isBusy: true,
            isTerminationPending: false
        ))
        precondition(!coordinator.consumeIfReady(
            isBusy: false,
            isTerminationPending: true
        ))
        precondition(coordinator.consumeIfReady(
            isBusy: false,
            isTerminationPending: false
        ))
        precondition(!coordinator.isRequested)

        _ = coordinator.requestIfBusy(true)
        coordinator.clear()
        precondition(!coordinator.isRequested)
        print("OK deferred-termination=queued-then-consumed")
    }
}
