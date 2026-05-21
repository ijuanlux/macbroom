import Foundation

@MainActor
final class SmartScanCoordinator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case ready(reclaimable: Int64, items: Int)
        case cleaning
        case done(reclaimed: Int64)
    }

    @Published private(set) var phase: Phase = .idle

    private let cacheScanner = CacheScanner()
    private let devJunkScanner = DevJunkScanner()

    func scan() async {
        guard phase != .scanning, phase != .cleaning else { return }
        phase = .scanning

        async let cache: Void = cacheScanner.scan()
        async let dev: Void = devJunkScanner.scan()
        _ = await (cache, dev)

        let bytes = cacheScanner.totalSize + devJunkScanner.totalSize
        let count = cacheScanner.items.count + devJunkScanner.items.count

        if bytes == 0 {
            phase = .done(reclaimed: 0)
        } else {
            phase = .ready(reclaimable: bytes, items: count)
        }
    }

    func cleanAll() async -> Int64 {
        guard case .ready = phase else { return 0 }
        phase = .cleaning

        let cacheItems = cacheScanner.items
        let devItems = devJunkScanner.items

        let cacheResult = await cacheScanner.clean(cacheItems)
        let devResult = await devJunkScanner.clean(devItems)

        let total = cacheResult.reclaimed + devResult.reclaimed
        phase = .done(reclaimed: total)
        return total
    }

    func reset() {
        phase = .idle
    }
}
