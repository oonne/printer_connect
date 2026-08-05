import 'package:flutter/material.dart';
import 'package:printer_connect/printer_connect.dart';

class ScannedItemWidget extends StatelessWidget {
  final BleDevice bleDevice;
  final VoidCallback? onTap;
  const ScannedItemWidget({super.key, required this.bleDevice, this.onTap});

  @override
  Widget build(BuildContext context) {
    String? name = bleDevice.name;
    List<ManufacturerData> rawManufacturerData = bleDevice.manufacturerDataList;
    ManufacturerData? manufacturerData;
    if (rawManufacturerData.isNotEmpty) {
      manufacturerData = rawManufacturerData.first;
    }
    if (name == null || name.isEmpty) name = '未知设备';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        child: ListTile(
          title: Text('$name (${bleDevice.rssi})'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bleDevice.deviceId),
              Visibility(
                visible: manufacturerData != null,
                child: Text(manufacturerData.toString()),
              ),
              if (bleDevice.timestampDateTime != null)
                Text("最后发现: ${bleDevice.timestampDateTime}"),
              bleDevice.paired == true
                  ? const Text("已配对", style: TextStyle(color: Colors.green))
                  : const Text(
                      "未配对",
                      style: TextStyle(color: Colors.red),
                    ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: onTap,
        ),
      ),
    );
  }
}
