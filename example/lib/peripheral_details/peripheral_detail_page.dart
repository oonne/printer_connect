import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect_example/peripheral_details/widgets/result_widget.dart';
import 'package:printer_connect_example/peripheral_details/widgets/services_list_widget.dart';
import 'package:printer_connect_example/widgets/platform_button.dart';
import 'package:printer_connect_example/widgets/responsive_buttons_grid.dart';
import 'package:printer_connect_example/widgets/responsive_view.dart';

class PeripheralDetailPage extends StatefulWidget {
  final BleDevice bleDevice;
  const PeripheralDetailPage(this.bleDevice, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _PeripheralDetailPageState();
  }
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage> {
  late final bleDevice = widget.bleDevice;
  bool isConnected = false;
  GlobalKey<FormState> valueFormKey = GlobalKey<FormState>();
  List<BleService> discoveredServices = [];
  final List<String> _logs = [];
  final binaryCode = TextEditingController();

  StreamSubscription? connectionStreamSubscription;
  StreamSubscription<Uint8List>? _valueSubscription;
  BleService? selectedService;
  BleCharacteristic? selectedCharacteristic;
  PrinterServiceInfo? printerServiceInfo;

  @override
  void initState() {
    super.initState();

    connectionStreamSubscription = bleDevice.connectionStream.listen(
      _handleConnectionChange,
    );
    PrinterConnectPlatform.instance.onConnectionParametersChange =
        _handleConnectionParametersChange;
    _asyncInits();
  }

  void _asyncInits() {
    bleDevice.connectionState.then((state) {
      if (state == BleConnectionState.connected) {
        setState(() {
          isConnected = true;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    connectionStreamSubscription?.cancel();
    _valueSubscription?.cancel();
    PrinterConnectPlatform.instance.onConnectionParametersChange = null;
  }

  void _addLog(String type, dynamic data) {
    setState(() {
      _logs.add('$type: ${data.toString()}');
    });
  }

  void _handleConnectionChange(bool isConnected) {
    debugPrint('_handleConnectionChange $isConnected');
    setState(() {
      this.isConnected = isConnected;
    });
    _addLog('连接', isConnected ? "已连接" : "已断开");
    if (this.isConnected) {
      _discoverServices();
    }
  }

  void _handleValueChange(Uint8List value) {
    String s = String.fromCharCodes(value);
    String data = '$s\nraw :  ${value.toString()}';
    debugPrint('_handleValueChange $s');
    _addLog("数值", data);
  }

  void _handleConnectionParametersChange(
    BleConnectionParametersUpdated update,
  ) {
    if (update.deviceId.toLowerCase() != bleDevice.deviceId.toLowerCase()) {
      return;
    }
    debugPrint('ConnectionParametersChange $update');
    _addLog(
      "连接参数变更",
      "间隔: ${update.interval} 延迟: ${update.latency} 监督超时: ${update.supervisionTimeout} 状态: ${update.status}",
    );
  }

  void _onCharacteristicSelected(
    BleService service,
    BleCharacteristic characteristic,
  ) {
    setState(() {
      selectedService = service;
      selectedCharacteristic = characteristic;
    });
    _valueSubscription?.cancel();
    _valueSubscription = characteristic.onValueReceived.listen(
      _handleValueChange,
    );
  }

  Future<void> _discoverServices() async {
    try {
      var services = await bleDevice.discoverServices(withDescriptors: false);
      debugPrint('${services.length} services discovered');
      debugPrint(services.toString());
      setState(() {
        discoveredServices = services;
      });
    } catch (e) {
      _addLog("发现服务错误", e);
    }
  }

  Future<void> _readValue() async {
    BleCharacteristic? selectedCharacteristic = this.selectedCharacteristic;
    if (selectedCharacteristic == null) return;
    try {
      Uint8List value = await selectedCharacteristic.read();
      String s = String.fromCharCodes(value);
      String data = '$s\nraw :  ${value.toString()}';
      _addLog('读取', data);
    } catch (e) {
      _addLog('读取错误', e);
    }
  }

  Future<void> _writeValue({required bool withResponse}) async {
    BleCharacteristic? selectedCharacteristic = this.selectedCharacteristic;
    if (selectedCharacteristic == null ||
        !valueFormKey.currentState!.validate() ||
        binaryCode.text.isEmpty) {
      return;
    }

    Uint8List value;
    try {
      value = Uint8List.fromList(hex.decode(binaryCode.text));
    } catch (e) {
      _addLog('写入错误', "解析十六进制出错: $e");
      return;
    }

    try {
      await selectedCharacteristic.write(value, withResponse: withResponse);
      _addLog(withResponse ? '写入' : '无响应写入', value);
    } catch (e) {
      debugPrint(e.toString());
      _addLog('写入错误', e);
    }
  }

  Future<void> _subscribeChar() async {
    BleCharacteristic? selectedCharacteristic = this.selectedCharacteristic;
    if (selectedCharacteristic == null) return;
    try {
      var subscription = _getCharacteristicSubscription(selectedCharacteristic);
      if (subscription == null) throw '该特征值不支持 notify 或 indicate 属性';
      await subscription.subscribe();
      _addLog('特征值订阅', '已订阅');
    } catch (e) {
      _addLog('通知错误', e);
    }
  }

  Future<void> _unsubscribeChar() async {
    try {
      await selectedCharacteristic?.unsubscribe();
      _addLog('特征值订阅', '已取消订阅');
    } catch (e) {
      _addLog('通知错误', e);
    }
  }

  CharacteristicSubscription? _getCharacteristicSubscription(
    BleCharacteristic characteristic,
  ) {
    var properties = characteristic.properties;
    if (properties.contains(CharacteristicProperty.notify)) {
      return characteristic.notifications;
    } else if (properties.contains(CharacteristicProperty.indicate)) {
      return characteristic.indications;
    }
    return null;
  }

  Future<void> _requestConnectionPriority() async {
    try {
      await PrinterConnect.requestConnectionPriority(
        bleDevice.deviceId,
        BleConnectionPriority.highPerformance,
      );
    } catch (e) {
      _addLog('请求连接优先级错误', e);
    }
  }

  Future<void> _initPrinterService() async {
    try {
      final info = await PrinterServiceFinder.initDevice(
        deviceId: bleDevice.deviceId,
        name: bleDevice.name ?? '',
      );
      setState(() {
        printerServiceInfo = info;
      });
      _addLog('获取打印服务',
          '成功 - service: ${info.service}, characteristic: ${info.characteristic}, labelCodeType: ${info.labelCodeType}');
    } catch (e) {
      setState(() {
        printerServiceInfo = null;
      });
      _addLog('获取打印服务错误 (${e.runtimeType})', e);
    }
  }

  Future<void> _testTspl() async {
    final info = printerServiceInfo;
    if (info == null) return;
    const tsplCommands = [
      'SIZE 50mm,30mm',
      'GAP 2mm',
      'CLS',
      'TEXT 40, 20,"4",0,1,1,"blog.oonne.com"',
      'PRINT 1,1',
    ];
    // 每条指令以 \r\n 结尾，拼接为完整 TSPL 数据
    final tsplData = '${tsplCommands.join('\r\n')}\r\n';
    final value = Uint8List.fromList(tsplData.codeUnits);
    try {
      await PrinterConnect.write(
        info.deviceId,
        info.service,
        info.characteristic,
        value,
      );
      _addLog('测试TSPL', '已发送 ${value.length} 字节');
    } catch (e) {
      _addLog('测试TSPL错误 (${e.runtimeType})', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${bleDevice.name ?? "未知设备"} - ${bleDevice.deviceId}"),
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.greenAccent : Colors.red,
              size: 20,
            ),
          ),
        ],
      ),
      body: ResponsiveView(
        builder: (context) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      PlatformButton(
                        text: '连接',
                        enabled: !isConnected,
                        onPressed: () async {
                          try {
                            await bleDevice.connect();
                            _addLog("连接结果", true);
                          } catch (e) {
                            _addLog('连接错误 (${e.runtimeType})', e);
                          }
                        },
                      ),
                      PlatformButton(
                        text: '断开连接',
                        enabled: isConnected,
                        onPressed: () async {
                          try {
                            await bleDevice.disconnect();
                            _addLog("断开连接结果", true);
                          } catch (e) {
                            _addLog('断开连接错误 (${e.runtimeType})', e);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                selectedCharacteristic == null
                    ? Text(
                        discoveredServices.isEmpty
                            ? "请发现服务"
                            : "请选择特征值",
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Card(
                          child: ListTile(
                            title: SelectableText(
                              "特征值: ${selectedCharacteristic?.uuid}",
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  "服务: ${selectedService?.uuid}",
                                ),
                                Text(
                                  "属性: ${selectedCharacteristic?.properties.map((e) => e.name)}",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                if (_hasSelectedCharacteristicProperty([
                  CharacteristicProperty.write,
                  CharacteristicProperty.writeWithoutResponse,
                ]))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Form(
                      key: valueFormKey,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          controller: binaryCode,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入数值';
                            }
                            try {
                              hex.decode(binaryCode.text);
                              return null;
                            } catch (e) {
                              return '请输入有效的十六进制值（不含空格或 0x，例如 F0BB）';
                            }
                          },
                          decoration: const InputDecoration(
                            hintText:
                                "请输入十六进制值，不含空格或 0x（例如 F0BB）",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ResponsiveButtonsGrid(
                    children: [
                      PlatformButton(
                        onPressed: () async {
                          _discoverServices();
                        },
                        enabled: isConnected,
                        text: '发现服务',
                      ),
                      PlatformButton(
                        onPressed: _initPrinterService,
                        enabled: isConnected,
                        text: '获取打印服务',
                      ),
                      if (printerServiceInfo != null)
                        PlatformButton(
                          onPressed: _testTspl,
                          enabled: isConnected,
                          text: '测试TSPL',
                        ),
                      PlatformButton(
                        onPressed: () async {
                          _addLog(
                            '连接状态',
                            await bleDevice.connectionState,
                          );
                        },
                        text: '连接状态',
                      ),
                      if (BleCapabilities.supportsConnectionParametersUpdates)
                        PlatformButton(
                          enabled: isConnected,
                          onPressed: () async {
                            _requestConnectionPriority();
                          },
                          text: '请求连接优先级',
                        ),
                      if (BleCapabilities.supportsRequestMtuApi)
                        PlatformButton(
                          enabled: isConnected,
                          onPressed: () async {
                            int mtu = await bleDevice.requestMtu(247);
                            _addLog('MTU', mtu);
                          },
                          text: '请求 MTU',
                        ),
                      PlatformButton(
                        enabled:
                            isConnected &&
                            discoveredServices.isNotEmpty &&
                            _hasSelectedCharacteristicProperty([
                              CharacteristicProperty.read,
                            ]),
                        onPressed: _readValue,
                        text: '读取',
                      ),
                      PlatformButton(
                        enabled:
                            isConnected &&
                            discoveredServices.isNotEmpty &&
                            _hasSelectedCharacteristicProperty([
                              CharacteristicProperty.write,
                            ]),
                        onPressed: () => _writeValue(withResponse: true),
                        text: '写入',
                      ),
                      PlatformButton(
                        enabled:
                            isConnected &&
                            discoveredServices.isNotEmpty &&
                            _hasSelectedCharacteristicProperty([
                              CharacteristicProperty.writeWithoutResponse,
                            ]),
                        onPressed: () => _writeValue(withResponse: false),
                        text: '无响应写入',
                      ),
                      PlatformButton(
                        enabled:
                            isConnected &&
                            discoveredServices.isNotEmpty &&
                            _hasSelectedCharacteristicProperty([
                              CharacteristicProperty.notify,
                              CharacteristicProperty.indicate,
                            ]),
                        onPressed: _subscribeChar,
                        text: '订阅',
                      ),
                      PlatformButton(
                        enabled:
                            isConnected &&
                            discoveredServices.isNotEmpty &&
                            _hasSelectedCharacteristicProperty([
                              CharacteristicProperty.notify,
                              CharacteristicProperty.indicate,
                            ]),
                        onPressed: _unsubscribeChar,
                        text: '取消订阅',
                      ),
                    ],
                  ),
                ),
                if (printerServiceInfo != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.print, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  "打印服务信息",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.label_outline),
                              title: const Text("设备名称"),
                              subtitle: SelectableText(
                                printerServiceInfo!.name,
                              ),
                            ),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.devices),
                              title: const Text("设备 ID"),
                              subtitle: SelectableText(
                                printerServiceInfo!.deviceId,
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.memory),
                              title: const Text("服务 UUID"),
                              subtitle: SelectableText(
                                printerServiceInfo!.service,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.album),
                              title: const Text("特征值 UUID"),
                              subtitle: SelectableText(
                                printerServiceInfo!.characteristic,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.description_outlined),
                              title: const Text("标签指令类型"),
                              subtitle: SelectableText(
                                printerServiceInfo!.labelCodeType,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ServicesListWidget(
                  discoveredServices: discoveredServices,
                  onTap: _onCharacteristicSelected,
                ),
                const Divider(),
                ResultWidget(
                  results: _logs,
                  onClearTap: (int? index) {
                    setState(() {
                      if (index != null) {
                        _logs.removeAt(index);
                      } else {
                        _logs.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasSelectedCharacteristicProperty(
    List<CharacteristicProperty> properties,
  ) {
    return properties.any(
      (property) =>
          selectedCharacteristic?.properties.contains(property) ?? false,
    );
  }
}
