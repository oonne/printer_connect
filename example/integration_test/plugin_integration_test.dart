import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:printer_connect/printer_connect.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getBluetoothAvailabilityState test', (WidgetTester tester) async {
    final state = await PrinterConnect.getBluetoothAvailabilityState();
    expect(state, isNotNull);
    expect(state, isA<AvailabilityState>());
  });
}