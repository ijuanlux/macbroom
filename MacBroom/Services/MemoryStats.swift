import Foundation
import Darwin.Mach

struct MemoryStats: Equatable {
    let total: Int64
    let free: Int64
    let active: Int64
    let inactive: Int64
    let wired: Int64
    let compressed: Int64
    let usedApps: Int64        // active + wired + compressed (rough "App memory")

    var used: Int64 { max(0, total - free) }

    static let zero = MemoryStats(total: 0, free: 0, active: 0, inactive: 0,
                                  wired: 0, compressed: 0, usedApps: 0)
}

enum MemoryReader {
    /// Reads VM statistics from the Mach kernel and returns a `MemoryStats` snapshot.
    static func current() -> MemoryStats {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var info = vm_statistics64_data_t()
        let entryCount = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(entryCount)

        let result = withUnsafeMutablePointer(to: &info) { (ptr: UnsafeMutablePointer<vm_statistics64_data_t>) -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: entryCount) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryStats(total: total, free: 0, active: 0, inactive: 0,
                               wired: 0, compressed: 0, usedApps: 0)
        }
        let pageSize = Int64(vm_kernel_page_size)
        let free       = Int64(info.free_count)             * pageSize
        let active     = Int64(info.active_count)           * pageSize
        let inactive   = Int64(info.inactive_count)         * pageSize
        let wired      = Int64(info.wire_count)             * pageSize
        let compressed = Int64(info.compressor_page_count)  * pageSize
        let usedApps   = active + wired + compressed
        return MemoryStats(total: total, free: free, active: active, inactive: inactive,
                           wired: wired, compressed: compressed, usedApps: usedApps)
    }
}
