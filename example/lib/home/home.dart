import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect_example/data/mock_printer_connect.dart';
import 'package:printer_connect_example/home/widgets/android_scan_options_widget.dart';
import 'package:printer_connect_example/home/widgets/scan_filter_widget.dart';
import 'package:printer_connect_example/home/widgets/scanned_devices_placeholder_widget.dart';
import 'package:printer_connect_example/home/widgets/scanned_item_widget.dart';
import 'package:printer_connect_example/peripheral_details/peripheral_detail_page.dart';
import 'package:printer_connect_example/widgets/platform_button.dart';
import 'package:printer_connect_example/widgets/responsive_buttons_grid.dart';

class CentralHome extends StatefulWidget {
  final bool showAppBar;
  const CentralHome({super.key, this.showAppBar = true});

  @override
  State createState() => _CentralHomeState();
}

class _CentralHomeState extends State<CentralHome> {
  final _bleDevices = <BleDevice>[];
  final _hiddenDevices = <BleDevice>[];
  bool _isScanning = false;
  TextEditingController servicesFilterController = TextEditingController();
  TextEditingController namePrefixController = TextEditingController();
  TextEditingController manufacturerDataController = TextEditingController();
  StreamSubscription<AvailabilityState>? _availabilityStreamSubscription;

  bool get isTrackingAvailabilityState =>
      _availabilityStreamSubscription != null;
  AvailabilityState? bleAvailabilityState;
  ScanFilter? scanFilter;
  AndroidOptions? _androidOptions;

  @override
  void initState() {
    super.initState();

    if (const bool.fromEnvironment('MOCK')) {
      PrinterConnect.setInstance(MockPrinterConnect());
    }

    PrinterConnect.timeout = const Duration(seconds: 10);

    PrinterConnect.scanStream.listen((result) {
      if (_hiddenDevices.any((e) => e.deviceId == result.deviceId)) {
        return;
      }
      int index = _bleDevices.indexWhere((e) => e.deviceId == result.deviceId);
      if (index == -1) {
        _bleDevices.add(result);
      } else {
        if (result.name == null && _bleDevices[index].name != null) {
          result.name = _bleDevices[index].name;
        }
        _bleDevices[index] = result;
      }
      setState(() {});
    });

    PrinterConnect.isScanning().then((value) {
      debugPrint("Is Scanning: $value");
      setState(() {
        _isScanning = value;
      });
    });
  }

  void trackAvailabilityState() {
    _availabilityStreamSubscription = PrinterConnect.availabilityStream.listen((
      state,
    ) {
      setState(() {
        bleAvailabilityState = state;
      });
    });
    setState(() {});
  }

  Future<void> startScan() async {
    final platformConfig = _androidOptions == null
        ? null
        : PlatformConfig(android: _androidOptions);
    await PrinterConnect.startScan(
      scanFilter: scanFilter,
      platformConfig: platformConfig,
    );
  }

  Future<void> _getSystemDevices() async {
    if ((defaultTargetPlatform == TargetPlatform.iOS) &&
        (scanFilter?.withServices ?? []).isEmpty) {
      showSnackbar(
        "未设置用于获取系统已连接设备的服务过滤器。将使用默认服务...",
      );
    }

    List<BleDevice> devices = await PrinterConnect.getSystemDevices(
      withServices: scanFilter?.withServices,
    );
    if (devices.isEmpty) {
      showSnackbar("未找到系统已连接的设备");
    }
    setState(() {
      _bleDevices.clear();
      _bleDevices.addAll(devices);
    });
  }

  void _showScanFilterBottomSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return ScanFilterWidget(
          servicesFilterController: servicesFilterController,
          namePrefixController: namePrefixController,
          manufacturerDataController: manufacturerDataController,
          onScanFilter: (ScanFilter? filter) {
            setState(() {
              scanFilter = filter;
            });
          },
        );
      },
    );
  }

  void _showAndroidScanOptionsBottomSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return AndroidScanOptionsWidget(
          initial: _androidOptions,
          onChanged: (AndroidOptions? options) {
            setState(() {
              _androidOptions = options;
            });
          },
        );
      },
    );
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _availabilityStreamSubscription?.cancel();
    servicesFilterController.dispose();
    namePrefixController.dispose();
    manufacturerDataController.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Printer Connect - 中心设备'),
              elevation: 4,
              actions: [
                if (_isScanning)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ResponsiveButtonsGrid(
              children: [
                PlatformButton(
                  text: '开始扫描',
                  onPressed: () async {
                    setState(() {
                      _bleDevices.clear();
                      _isScanning = true;
                    });
                    try {
                      await startScan();
                    } catch (e) {
                      setState(() {
                        _isScanning = false;
                      });
                      showSnackbar(e.toString());
                    }
                  },
                ),
                PlatformButton(
                  text: '停止扫描',
                  onPressed: () async {
                    await PrinterConnect.stopScan();
                    setState(() {
                      _isScanning = false;
                    });
                  },
                ),
                if (BleCapabilities.supportsBluetoothEnableApi)
                  bleAvailabilityState != AvailabilityState.poweredOn
                      ? PlatformButton(
                          text: '开启蓝牙',
                          onPressed: () async {
                            bool isEnabled =
                                await PrinterConnect.enableBluetooth();
                            showSnackbar("蓝牙已开启: $isEnabled");
                          },
                        )
                      : PlatformButton(
                          text: '关闭蓝牙',
                          onPressed: () async {
                            bool isDisabled =
                                await PrinterConnect.disableBluetooth();
                            showSnackbar("蓝牙已关闭: $isDisabled");
                          },
                        ),
                if (BleCapabilities.requiresRuntimePermission) ...[
                  PlatformButton(
                    text: '是否已授予权限',
                    onPressed: () async {
                      try {
                        bool granted = await PrinterConnect.hasPermissions(
                          withAndroidFineLocation: false,
                        );
                        showSnackbar("是否已授予权限: $granted");
                      } catch (e) {
                        showSnackbar(e.toString());
                      }
                    },
                  ),
                  PlatformButton(
                    text: '请求权限',
                    onPressed: () async {
                      try {
                        await PrinterConnect.requestPermissions(
                          withAndroidFineLocation: false,
                        );
                        showSnackbar("权限已授予");
                      } catch (e) {
                        showSnackbar(e.toString());
                      }
                    },
                  ),
                ],
                if (!isTrackingAvailabilityState)
                  PlatformButton(
                    text: '跟踪可用性状态',
                    onPressed: trackAvailabilityState,
                  ),
                if (BleCapabilities.supportsConnectedDevicesApi)
                  PlatformButton(
                    text: '系统设备',
                    onPressed: _getSystemDevices,
                  ),
                PlatformButton(
                  text: '扫描过滤器',
                  onPressed: _showScanFilterBottomSheet,
                ),
                PlatformButton(
                  text: _androidOptions == null
                      ? 'Android 扫描选项'
                      : 'Android 扫描选项 •',
                  onPressed: _showAndroidScanOptionsBottomSheet,
                ),
                if (_hiddenDevices.isNotEmpty)
                  PlatformButton(
                    text: '取消隐藏 ${_hiddenDevices.length} 个设备',
                    onPressed: () {
                      setState(() {
                        _hiddenDevices.clear();
                      });
                    },
                  )
                else if (_bleDevices.isNotEmpty)
                  Tooltip(
                    message:
                        '隐藏已发现的设备。当开启新设备时，将更容易发现它。',
                    child: PlatformButton(
                      text: '隐藏已发现的设备',
                      onPressed: () {
                        setState(() {
                          _hiddenDevices.clear();
                          _hiddenDevices.addAll(_bleDevices);
                          _bleDevices.clear();
                        });
                      },
                    ),
                  ),
                if (_bleDevices.isNotEmpty)
                  PlatformButton(
                    text: '清空列表',
                    onPressed: () {
                      setState(() {
                        _bleDevices.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isTrackingAvailabilityState)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '蓝牙可用性 : ${bleAvailabilityState?.name}',
                  ),
                ),
            ],
          ),
          const Divider(color: Colors.blue),
          Expanded(
            child: _isScanning && _bleDevices.isEmpty
                ? const Center(child: CircularProgressIndicator.adaptive())
                : !_isScanning && _bleDevices.isEmpty
                ? const ScannedDevicesPlaceholderWidget()
                : ListView.separated(
                    itemCount: _bleDevices.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      BleDevice device =
                          _bleDevices[_bleDevices.length - index - 1];
                      return ScannedItemWidget(
                        bleDevice: device,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PeripheralDetailPage(device),
                            ),
                          );
                          PrinterConnect.stopScan();
                          setState(() {
                            _isScanning = false;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
