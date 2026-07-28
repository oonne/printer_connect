import 'package:flutter/material.dart';

import 'package:printer_connect/printer_connect.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AvailabilityState _availabilityState = AvailabilityState.unknown;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    final state = await PrinterConnect.getBluetoothAvailabilityState();
    final hasPermissions = await PrinterConnect.hasPermissions();

    if (!mounted) return;

    setState(() {
      _availabilityState = state;
      _hasPermissions = hasPermissions;
    });
  }

  Future<void> _startScan() async {
    try {
      await PrinterConnect.startScan();
    } catch (e) {
      debugPrint('Start scan failed: $e');
    }
  }

  Future<void> _stopScan() async {
    try {
      await PrinterConnect.stopScan();
    } catch (e) {
      debugPrint('Stop scan failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Printer Connect Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Bluetooth: ${_availabilityState.name}'),
              Text('Permissions: $_hasPermissions'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Start Scan'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _stopScan,
                child: const Text('Stop Scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}