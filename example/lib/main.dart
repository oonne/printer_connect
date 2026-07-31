import 'package:flutter/material.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect_example/home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrinterConnect.setLogLevel(BleLogLevel.verbose);
  runApp(
    MaterialApp(
      title: 'Printer Connect',
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const CentralHome(),
    ),
  );
}
