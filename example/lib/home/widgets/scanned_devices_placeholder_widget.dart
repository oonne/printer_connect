import 'package:flutter/material.dart';

class ScannedDevicesPlaceholderWidget extends StatelessWidget {
  const ScannedDevicesPlaceholderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.bluetooth, color: Colors.grey, size: 100),
        ),
        Text(
          '扫描设备',
          style: TextStyle(color: Colors.grey, fontSize: 22),
        ),
      ],
    );
  }
}
