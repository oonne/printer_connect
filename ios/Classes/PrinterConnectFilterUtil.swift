import Foundation
import CoreBluetooth

extension UniversalScanFilter {
    var usesCustomFilters: Bool {
        return withServices != nil || withManufacturerData != nil || withLocalName != nil || withLocalNamePrefix != nil
    }
}

struct PrinterConnectFilterUtil {

    static func filterDevice(
        _ peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber,
        filters: [UniversalScanFilter]?
    ) -> UniversalBleScanResult? {
        let peripheralId = peripheral.identifier.uuidString
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name

        var manufacturerDataList: [UniversalManufacturerData]? = nil
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            let manufacturerId = Int64(manufacturerData.prefix(2).withUnsafeBytes {
                $0.load(as: UInt16.self)
            })
            let data = manufacturerData.dropFirst(2).map { Int64($0) }
            manufacturerDataList = [UniversalManufacturerData(id: manufacturerId, data: data)]
        }

        var serviceUuids: [String]? = nil
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            serviceUuids = services.map { $0.uuidString }
        }

        var txPowerLevel: Int64? = nil
        if let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            txPowerLevel = txPower.int64Value
        }

        let result = UniversalBleScanResult(
            peripheralId: peripheralId,
            name: name,
            rssi: rssi.int64Value,
            manufacturerData: manufacturerDataList,
            serviceData: nil,
            serviceUuids: serviceUuids,
            txPowerLevel: txPowerLevel
        )

        guard let filters = filters, !filters.isEmpty else {
            return result
        }

        for filter in filters {
            if isNameMatchingFilters(filter: filter, name: name) &&
                isServicesMatchingFilters(filter: filter, serviceUuids: serviceUuids) &&
                isManufacturerDataMatchingFilters(filter: filter, manufacturerData: manufacturerDataList) {
                return result
            }
        }

        return nil
    }

    static func isNameMatchingFilters(filter: UniversalScanFilter, name: String?) -> Bool {
        guard filter.withLocalName != nil || filter.withLocalNamePrefix != nil else {
            return true
        }

        guard let name = name else {
            return false
        }

        if let localName = filter.withLocalName {
            if name != localName {
                return false
            }
        }

        if let prefix = filter.withLocalNamePrefix {
            if !name.hasPrefix(prefix) {
                return false
            }
        }

        return true
    }

    static func isServicesMatchingFilters(filter: UniversalScanFilter, serviceUuids: [String]?) -> Bool {
        guard let filterServices = filter.withServices, !filterServices.isEmpty else {
            return true
        }

        guard let serviceUuids = serviceUuids, !serviceUuids.isEmpty else {
            return false
        }

        for filterService in filterServices {
            if !serviceUuids.contains(filterService) {
                return false
            }
        }

        return true
    }

    static func isManufacturerDataMatchingFilters(filter: UniversalScanFilter, manufacturerData: [UniversalManufacturerData]?) -> Bool {
        guard let filterManufacturerData = filter.withManufacturerData, !filterManufacturerData.isEmpty else {
            return true
        }

        guard let manufacturerData = manufacturerData, !manufacturerData.isEmpty else {
            return false
        }

        for filterEntry in filterManufacturerData {
            guard let matchingEntry = manufacturerData.first(where: { $0.id == filterEntry.companyId }) else {
                return false
            }

            guard let filterData = filterEntry.data, !filterData.isEmpty else {
                continue
            }

            guard let filterMask = filterEntry.mask, !filterMask.isEmpty else {
                if matchingEntry.data != filterData {
                    return false
                }
                continue
            }

            for i in 0..<filterData.count {
                if i >= matchingEntry.data.count {
                    return false
                }
                let maskByte = filterMask[i]
                if maskByte == 0 {
                    continue
                }
                if matchingEntry.data[i] != filterData[i] {
                    return false
                }
            }
        }

        return true
    }
}