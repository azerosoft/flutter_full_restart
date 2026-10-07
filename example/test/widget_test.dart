// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter_full_restart_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the times and the restart buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());

    expect(find.text('Dart session started'), findsOneWidget);
    expect(find.text('Screen built'), findsOneWidget);
    expect(find.text('UI restart'), findsOneWidget);
    expect(find.text('Full restart'), findsOneWidget);
  });
}
