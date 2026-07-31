import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlatformButton extends StatelessWidget {
  final String text;
  final void Function()? onPressed;
  final bool enabled;

  const PlatformButton({
    required this.text,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return (Platform.isIOS)
        ? CupertinoButton.filled(
            onPressed: enabled ? onPressed : null,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            disabledColor: Colors.grey,
            child: Text(text),
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            child: Text(text),
          );
  }
}
