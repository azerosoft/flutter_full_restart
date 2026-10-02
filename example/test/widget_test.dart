// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter_full_restart_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the restart buttons', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Full restart with confirmation'),
      200,
    );

    expect(find.text('UI restart'), findsOneWidget);
    expect(find.text('Full restart'), findsOneWidget);
    expect(find.text('Full restart with confirmation'), findsOneWidget);
  });
}
