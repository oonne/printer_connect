import CoreBluetooth
import Foundation

/// 扫描过滤器工具类。
///
/// 支持三种自定义过滤条件：
/// - 设备名称前缀匹配
/// - 服务 UUID 匹配
/// - 制造商数据（Company ID + Payload 前缀 + 掩码）匹配
/// 多个条件之间采用 OR 逻辑（任一条件满足即通过）。
class PrinterConnectFilterUtil {

    /// 自定义扫描过滤器配置（来自 Dart 层的 UniversalScanFilter）
    var scanFilter: UniversalScanFilter?
    /// 预解析的服务 UUID 列表（用于快速匹配）
    var scanFilterServicesUUID: [CBUUID] = []

    /// 判断外设是否通过过滤器。
    /// 采用 OR 逻辑：名称前缀匹配 || 服务 UUID 匹配 || 制造商数据匹配。
    /// 如果没有配置任何过滤条件，默认通过。
    func filterDevice(name: String?, manufacturerData: UniversalManufacturerData?, services: [CBUUID]?) -> Bool {
        guard let filter = scanFilter else {
            return true
        }
        let hasNamePrefixFilter = !filter.withNamePrefix.isEmpty
        let hasServiceFilter = !filter.withServices.isEmpty
        let hasManufacturerDataFilter = !filter.withManufacturerData.isEmpty

        if !hasNamePrefixFilter && !hasServiceFilter && !hasManufacturerDataFilter {
            return true
        }

        return hasNamePrefixFilter && isNameMatchingFilters(filter: filter, name: name) ||
            hasServiceFilter && isServicesMatchingFilters(services: services) ||
            hasManufacturerDataFilter && isManufacturerDataMatchingFilters(scanFilter: filter, msd: manufacturerData)
    }

    /// 检查设备名称是否匹配名称前缀过滤条件。
    /// 只要设备名称以任意一个配置的前缀开头即通过。
    func isNameMatchingFilters(filter: UniversalScanFilter, name: String?) -> Bool {
        let prefixFilters = filter.withNamePrefix.compactMap { $0 }.filter { !$0.isEmpty }
        guard !prefixFilters.isEmpty else {
            return true
        }
        guard let name = name, !name.isEmpty else {
            return false
        }
        return prefixFilters.contains { name.hasPrefix($0) }
    }

    /// 检查广播中的服务 UUID 是否与过滤条件有交集。
    /// 使用集合交集判断：只要广播服务中包含任意一个被过滤的服务即通过。
    func isServicesMatchingFilters(services: [CBUUID]?) -> Bool {
        let serviceFilters = Set(scanFilterServicesUUID.compactMap { $0 })
        guard !serviceFilters.isEmpty else {
            return true
        }
        guard let services = services, !services.isEmpty else {
            return false
        }
        return !Set(services).isDisjoint(with: serviceFilters)
    }

    /// 检查制造商数据是否匹配过滤条件。
    /// 依次比较每个过滤规则：先匹配 Company Identifier，再通过 findData 进行 Payload 前缀+掩码匹配。
    func isManufacturerDataMatchingFilters(scanFilter: UniversalScanFilter, msd: UniversalManufacturerData?) -> Bool {
        let filters = scanFilter.withManufacturerData.compactMap { $0 }
        if filters.isEmpty {
            return true
        }
        guard let msd = msd else {
            return false
        }
        for filter in filters {
            let companyIdentifier: Int64 = filter.companyIdentifier
            if msd.companyIdentifier == companyIdentifier && findData(find: filter.payloadPrefix?.toData(), inData: msd.data.toData(), usingMask: filter.payloadMask?.toData()) {
                return true
            }
        }
        return false
    }

    /// 在数据中查找匹配的字节序列。
    /// 使用掩码（mask）逐字节进行 AND 比较，实现灵活的字节匹配逻辑。
    /// 如果 find 为 nil 或空，直接返回 true。
    func findData(find: Data?, inData data: Data, usingMask mask: Data?) -> Bool {
        if let find = find {
            let mask = mask ?? Data(repeating: 0xFF, count: find.count)
            guard find.count == mask.count else {
                return false
            }
            for i in 0 ..< find.count {
                if (find[i] & mask[i]) != (data[i] & mask[i]) {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - UniversalScanFilter 扩展

extension UniversalScanFilter {
    /// 判断是否使用了自定义过滤器（制造商数据过滤或名称前缀过滤）
    /// 如果使用了自定义过滤器，系统级服务过滤将被禁用，由自定义逻辑全权处理
    var usesCustomFilters: Bool {
        return !withManufacturerData.isEmpty || !withNamePrefix.isEmpty
    }
}
