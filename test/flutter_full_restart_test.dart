// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_full_restart/flutter_full_restart.dart';
import 'package:flutter_full_restart/src/method_channel_full_restart.dart';
import 'package:flutter_full_restart/src/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> calls = <MethodCall>[];
  Object? Function(MethodCall call) reply = (_) => true;

  setUp(() {
    calls.clear();
    reply = (_) => true;
    FullRestartPlatform.instance = MethodChannelFullRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelFullRestart.channel,
            (MethodCall call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelFullRestart.channel, null);
  });

  /// Simulates the native side asking Dart to rebuild its widget tree.
  Future<void> sendRebuildSignal() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      kSignalChannel,
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall(kRebuildWidgetTreeSignal)),
      (_) {},
    );
  }

  group('FullRestart.restart', () {
    test('defaults to a full restart', () async {
      expect(await FullRestart.restart(), isTrue);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'restart');
      expect(calls.single.arguments, <String, bool>{'killProcess': true});
    });

    test('keeps the process for a UI restart', () async {
      expect(await FullRestart.restart(type: RestartType.ui), isTrue);

      expect(calls.single.arguments, <String, bool>{'killProcess': false});
    });

    test('returns false when the platform throws', () async {
      reply = (_) => throw PlatformException(code: 'NO_ACTIVITY');

      expect(await FullRestart.restart(), isFalse);
    });

    test('returns false when the platform replies with null', () async {
      reply = (_) => null;

      expect(await FullRestart.restart(), isFalse);
    });

    test('uses the registered platform implementation', () async {
      final _FakePlatform fake = _FakePlatform();
      FullRestartPlatform.instance = fake;

      expect(await FullRestart.restart(), isTrue);
      expect(fake.killProcess, isTrue);
      expect(calls, isEmpty);
    });
  });

  group('FullRestartScope', () {
    testWidgets('rebuilds its subtree from scratch on a rebuild signal',
        (WidgetTester tester) async {
      await tester.pumpWidget(const FullRestartScope(child: _Counter()));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await sendRebuildSignal();
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
    });

    // Registers a global callback, so it must stay the last test.
    testWidgets('calls onUiRestart instead of rebuilding when provided',
        (WidgetTester tester) async {
      int callbacks = 0;
      FullRestart.ensureInitialized(onUiRestart: () => callbacks++);
      await tester.pumpWidget(const FullRestartScope(child: _Counter()));
      await tester.tap(find.byType(_Counter));
      await tester.pump();

      await sendRebuildSignal();
      await tester.pump();

      expect(callbacks, 1);
      expect(find.text('1'), findsOneWidget);
    });
  });
}

class _FakePlatform extends FullRestartPlatform {
  bool? killProcess;

  @override
  Future<bool> restart({required bool killProcess}) async {
    this.killProcess = killProcess;
    return true;
  }
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _taps++),
      child: Text('$_taps', textDirection: TextDirection.ltr),
    );
  }
}
