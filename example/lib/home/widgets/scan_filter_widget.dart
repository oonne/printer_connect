import 'package:flutter/material.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect_example/widgets/platform_button.dart';

class ScanFilterWidget extends StatefulWidget {
  final void Function(ScanFilter? filter) onScanFilter;
  final TextEditingController servicesFilterController;
  final TextEditingController namePrefixController;
  final TextEditingController manufacturerDataController;

  const ScanFilterWidget({
    super.key,
    required this.onScanFilter,
    required this.servicesFilterController,
    required this.namePrefixController,
    required this.manufacturerDataController,
  });

  @override
  State<ScanFilterWidget> createState() => _ScanFilterWidgetState();
}

class _ScanFilterWidgetState extends State<ScanFilterWidget> {
  String? error;

  void applyFilter() {
    setState(() {
      error = null;
    });
    try {
      List<String> serviceUUids = [];
      List<String> namePrefixes = [];
      List<ManufacturerDataFilter> manufacturerDataFilters = [];

      if (widget.servicesFilterController.text.isNotEmpty) {
        List<String> services = widget.servicesFilterController.text.split(',');
        for (String service in services) {
          try {
            serviceUUids.add(BleUuidParser.string(service.trim()));
          } on FormatException catch (_) {
            throw Exception("无效的服务 UUID $service");
          }
        }
      }

      String namePrefix = widget.namePrefixController.text;
      if (namePrefix.isNotEmpty) {
        namePrefixes = namePrefix.split(',').map((e) => e.trim()).toList();
      }

      String manufacturerDataText = widget.manufacturerDataController.text;
      if (manufacturerDataText.isNotEmpty) {
        List<String> manufacturerData = manufacturerDataText.split(',');
        for (String manufacturer in manufacturerData) {
          int? companyIdentifier = int.tryParse(manufacturer);
          if (companyIdentifier == null) {
            throw Exception("无效的厂商数据 $manufacturer");
          }
          manufacturerDataFilters.add(
            ManufacturerDataFilter(companyIdentifier: companyIdentifier),
          );
        }
      }

      if (serviceUUids.isEmpty &&
          namePrefixes.isEmpty &&
          manufacturerDataFilters.isEmpty) {
        widget.onScanFilter(null);
      } else {
        widget.onScanFilter(
          ScanFilter(
            withServices: serviceUUids,
            withNamePrefix: namePrefixes,
            withManufacturerData: manufacturerDataFilters,
          ),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("过滤器已应用")));
      }
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  void clearFilter() {
    widget.servicesFilterController.clear();
    widget.namePrefixController.clear();
    widget.manufacturerDataController.clear();
    widget.onScanFilter(null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.copyWith(left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Text(
              "扫描过滤器",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Text("使用逗号添加多个值"),
          const Divider(),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.namePrefixController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "名称前缀",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.servicesFilterController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "服务",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.manufacturerDataController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "厂商数据公司 ID",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: PlatformButton(text: '应用', onPressed: applyFilter),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlatformButton(text: '清除', onPressed: clearFilter),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
