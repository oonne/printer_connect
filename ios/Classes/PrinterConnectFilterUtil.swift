import Foundation
import CoreBluetooth

extension UniversalScanFilter {
    var usesCustomFilters: Bool {
        return !withServices.isEmpty || !withManufacturerData.isEmpty || !withNamePrefix.isEmpty
    }
}

struct PrinterConnectFilterUtil {

    static func filterDevice(
        _ peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber,
        filter: UniversalScanFilter?
    ) -> UniversalBleScanResult? {
        let peripheralId = peripheral.identifier.uuidString
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name

        var manufacturerDataList: [UniversalManufacturerData]? = nil
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            let companyId = Int64(manufacturerData.prefix(2).withUnsafeBytes {
                $0.load(as: UInt16.self)
            })
            let data = FlutterStandardTypedData(bytes: manufacturerData.dropFirst(2))
            manufacturerDataList = [UniversalManufacturerData(companyIdentifier: companyId, data: data)]
        }

        var serviceUuids: [String]? = nil
        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            serviceUuids = services.map { $0.uuidString }
        }

        let result = UniversalBleScanResult(
            deviceId: peripheralId,
            name: name,
            isPaired: nil,
            rssi: rssi.int64Value,
            manufacturerDataList: manufacturerDataList,
            serviceData: nil,
            services: serviceUuids,
            timestamp: nil
        )

        guard let filter = filter else {
            return result
        }

        if isNameMatchingFilters(filter: filter, name: name) &&
            isServicesMatchingFilters(filter: filter, serviceUuids: serviceUuids) &&
            isManufacturerDataMatchingFilters(filter: filter, manufacturerData: manufacturerDataList) {
            return result
        }

        return nil
    }

    static func isNameMatchingFilters(filter: UniversalScanFilter, name: String?) -> Bool {
        guard !filter.withNamePrefix.isEmpty else {
            return true
        }

        guard let name = name else {
            return false
        }

        for prefix in filter.withNamePrefix {
            if !name.hasPrefix(prefix) {
                return false
            }
        }

        return true
    }

    static func isServicesMatchingFilters(filter: UniversalScanFilter, serviceUuids: [String]?) -> Bool {
        guard !filter.withServices.isEmpty else {
            return true
        }

        guard let serviceUuids = serviceUuids, !serviceUuids.isEmpty else {
            return false
        }

        for filterService in filter.withServices {
            if !serviceUuids.contains(filterService) {
                return false
            }
        }

        return true
    }

    static func isManufacturerDataMatchingFilters(filter: UniversalScanFilter, manufacturerData: [UniversalManufacturerData]?) -> Bool {
        guard !filter.withManufacturerData.isEmpty else {
            return true
        }

        guard let manufacturerData = manufacturerData, !manufacturerData.isEmpty else {
            return false
        }

        for filterEntry in filter.withManufacturerData {
            guard let matchingEntry = manufacturerData.first(where: { $0.companyIdentifier == filterEntry.companyIdentifier }) else {
                return false
            }

            let matchingData = matchingEntry.data.data

            guard let prefix = filterEntry.payloadPrefix, !prefix.isEmpty else {
                continue
            }

            let prefixData = prefix.data

            guard let mask = filterEntry.payloadMask, !mask.isEmpty else {
                if matchingData.prefix(prefixData.count) != prefixData {
                    return false
                }
                continue
            }

            let maskData = mask.data

            for i in 0..<prefixData.count {
                if i >= matchingData.count {
                    return false
                }
                let maskByte = maskData[i]
                if maskByte == 0 {
                    continue
                }
                if matchingData[i] != prefixData[i] {
                    return false
                }
            }
        }

        return true
    }
}