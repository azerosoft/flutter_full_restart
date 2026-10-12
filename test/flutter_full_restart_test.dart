// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_full_restart/flutter_full_restart.dart';
import 'package:flutter_full_restart/src/method_channel_full_restart.dart';
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

  group('FullRestart.restart', () {
    test('asks the native side for a full restart', () async {
      expect(await FullRestart.restart(), isTrue);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'restart');
      expect(calls.single.arguments, isNull);
    });

    test('returns false when the platform throws', () async {
      reply = (_) => throw PlatformException(code: 'NO_ACTIVITY');

      expect(await FullRestart.restart(), isFalse);
    });

    test('prints the native explanation in yellow when setup is missing',
        () async {
      reply = (_) => throw PlatformException(
            code: 'URL_SCHEME_MISSING',
            message: 'Full restart is not available on iOS.\nAdd the scheme.',
          );
      final List<String?> printed = <String?>[];
      final DebugPrintCallback originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
      try {
        expect(await FullRestart.restart(), isFalse);
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(printed, <String>[
        '\x1B[33m[flutter_full_restart] Full restart is not available on iOS.\x1B[0m',
        '\x1B[33m[flutter_full_restart] Add the scheme.\x1B[0m',
      ]);
    });

    test('returns false when the platform replies with null', () async {
      reply = (_) => null;

      expect(await FullRestart.restart(), isFalse);
    });

    test('uses the registered platform implementation', () async {
      final _FakePlatform fake = _FakePlatform();
      FullRestartPlatform.instance = fake;

      expect(await FullRestart.restart(), isTrue);
      expect(fake.restarts, 1);
      expect(calls, isEmpty);
    });
  });

  group('FullRestart.isRestartLink', () {
    test('accepts the link a full restart reopens the app with', () {
      expect(
          FullRestart.isRestartLink(Uri.parse('com.example.app://')), isTrue);
      expect(
          FullRestart.isRestartLink(Uri.parse('com.example.app:///')), isTrue);
    });

    test('rejects every other link', () {
      for (final String link in <String>[
        'com.example.app://product/42',
        'com.example.app:///product',
        'com.example.app://?tab=2',
        'com.example.app://#top',
        'https://example.com',
        'https://example.com/product/42',
        '/product/42',
      ]) {
        expect(FullRestart.isRestartLink(Uri.parse(link)), isFalse,
            reason: link);
      }
    });
  });
}

class _FakePlatform extends FullRestartPlatform {
  int restarts = 0;

  @override
  Future<bool> restart() async {
    restarts++;
    return true;
  }
}
