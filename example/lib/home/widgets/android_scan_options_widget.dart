import 'package:flutter/material.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect_example/widgets/platform_button.dart';

class AndroidScanOptionsWidget extends StatefulWidget {
  final AndroidOptions? initial;
  final void Function(AndroidOptions? options) onChanged;

  const AndroidScanOptionsWidget({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<AndroidScanOptionsWidget> createState() =>
      _AndroidScanOptionsWidgetState();
}

class _AndroidScanOptionsWidgetState extends State<AndroidScanOptionsWidget> {
  AndroidScanMode? _scanMode;
  final TextEditingController _reportDelayController = TextEditingController();
  final Set<AndroidScanCallbackType> _callbackType = {};
  AndroidScanMatchMode? _matchMode;
  AndroidScanNumOfMatches? _numOfMatches;
  bool? _legacy;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _scanMode = initial.scanMode;
      _reportDelayController.text = initial.reportDelayMillis?.toString() ?? '';
      _callbackType.addAll(initial.callbackType ?? const []);
      _matchMode = initial.matchMode;
      _numOfMatches = initial.numOfMatches;
      _legacy = initial.legacy;
    }
  }

  @override
  void dispose() {
    _reportDelayController.dispose();
    super.dispose();
  }

  AndroidOptions? _build() {
    final delayText = _reportDelayController.text.trim();
    final reportDelay = delayText.isEmpty ? null : int.tryParse(delayText);
    final hasAny =
        _scanMode != null ||
        reportDelay != null ||
        _callbackType.isNotEmpty ||
        _matchMode != null ||
        _numOfMatches != null ||
        _legacy != null;
    if (!hasAny) return null;
    return AndroidOptions(
      scanMode: _scanMode,
      reportDelayMillis: reportDelay,
      callbackType: _callbackType.isEmpty
          ? null
          : _callbackType.toList(growable: false),
      matchMode: _matchMode,
      numOfMatches: _numOfMatches,
      legacy: _legacy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsets + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Android 扫描选项',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              '所有字段均为可选。全部留空时将使用平台默认值进行扫描'
              '（等同于省略 platformConfig）。',
            ),
            const SizedBox(height: 16),
            _SectionTitle('scanMode'),
            _SingleSelect<AndroidScanMode>(
              values: AndroidScanMode.values,
              selected: _scanMode,
              label: (v) => v.name,
              onChanged: (v) => setState(() => _scanMode = v),
            ),
            const SizedBox(height: 16),
            _SectionTitle('reportDelayMillis'),
            TextField(
              controller: _reportDelayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '例如 0（立即）或 1000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              'callbackType（多选；由插件按位或合并）',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: AndroidScanCallbackType.values
                  .map(
                    (v) => FilterChip(
                      label: Text(v.name),
                      selected: _callbackType.contains(v),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _callbackType.add(v);
                        } else {
                          _callbackType.remove(v);
                        }
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            _SectionTitle('legacy'),
            const Text(
              'null/false：BLE 5 扩展广播（库默认值）。'
              'true：传统 BLE 4.x 广播（API 26+）。',
            ),
            const SizedBox(height: 8),
            _SingleSelect<bool>(
              values: const [true, false],
              selected: _legacy,
              label: (v) => v ? 'true' : 'false',
              onChanged: (v) => setState(() => _legacy = v),
            ),
            const SizedBox(height: 16),
            _SectionTitle('matchMode'),
            _SingleSelect<AndroidScanMatchMode>(
              values: AndroidScanMatchMode.values,
              selected: _matchMode,
              label: (v) => v.name,
              onChanged: (v) => setState(() => _matchMode = v),
            ),
            const SizedBox(height: 16),
            _SectionTitle('numOfMatches'),
            _SingleSelect<AndroidScanNumOfMatches>(
              values: AndroidScanNumOfMatches.values,
              selected: _numOfMatches,
              label: (v) => v.name,
              onChanged: (v) => setState(() => _numOfMatches = v),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PlatformButton(
                    text: '重置',
                    onPressed: () {
                      setState(() {
                        _scanMode = null;
                        _reportDelayController.clear();
                        _callbackType.clear();
                        _matchMode = null;
                        _numOfMatches = null;
                        _legacy = null;
                      });
                      widget.onChanged(null);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PlatformButton(
                    text: '应用',
                    onPressed: () {
                      widget.onChanged(_build());
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

class _SingleSelect<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T value) label;
  final void Function(T? value) onChanged;

  const _SingleSelect({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('— （默认）'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        ...values.map(
          (v) => ChoiceChip(
            label: Text(label(v)),
            selected: selected == v,
            onSelected: (sel) => onChanged(sel ? v : null),
          ),
        ),
      ],
    );
  }
}
