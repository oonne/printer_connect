import 'package:flutter/material.dart';

class ResponsiveView extends StatelessWidget {
  final Widget Function(BuildContext context) builder;
  const ResponsiveView({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return builder(ctx);
      },
    );
  }
}
