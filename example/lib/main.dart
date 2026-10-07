// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/material.dart';
import 'package:flutter_full_restart/flutter_full_restart.dart';

/// Set once per Dart isolate: changes after a full restart (and after a UI
/// restart on Android, which boots a new Flutter engine).
final DateTime sessionStartedAt = DateTime.now();

/// Azerosoft brand colours.
const Color azerosoftBlue = Color(0xFF2C55F0);
const Color azerosoftBlueDark = Color(0xFF7390FF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FullRestartScope(child: DemoApp()));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Full Restart',
      debugShowCheckedModeBanner: false,
      theme: _theme(
        ColorScheme.fromSeed(seedColor: azerosoftBlue).copyWith(
          primary: azerosoftBlue,
          onPrimary: Colors.white,
        ),
      ),
      darkTheme: _theme(
        ColorScheme.fromSeed(
          seedColor: azerosoftBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: azerosoftBlueDark,
          onPrimary: const Color(0xFF0D1016),
        ),
      ),
      home: const DemoPage(),
    );
  }

  /// Large buttons and text, so the app stays readable in small screenshots.
  static ThemeData _theme(ColorScheme colors) {
    const TextStyle label =
        TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
    const Size minimumSize = Size(64, 64);
    return ThemeData(
      colorScheme: colors,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumSize,
          textStyle: label,
        ),
      ),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  /// Set when this State is created: changes after any kind of restart.
  final DateTime _screenBuiltAt = DateTime.now();

  Future<void> _restart(RestartType type) async {
    final bool accepted = await FullRestart.restart(type: type);
    if (accepted || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The restart could not be started.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'flutter_full_restart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'What survives\na restart?',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _TimeTile(
                    icon: Icons.memory,
                    label: 'Dart session started',
                    time: sessionStartedAt,
                    highlight: true,
                  ),
                  const SizedBox(height: 14),
                  _TimeTile(
                    icon: Icons.widgets_outlined,
                    label: 'Screen built',
                    time: _screenBuiltAt,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => _restart(RestartType.ui),
                    icon: const Icon(Icons.refresh, size: 26),
                    label: const Text('UI restart'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _restart(RestartType.full),
                    icon: const Icon(Icons.power_settings_new, size: 26),
                    label: const Text('Full restart'),
                  ),
                  const SizedBox(height: 28),
                  const _MadeByAzerosoft(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A clock time with a label, e.g. when the Dart session started.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.time,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final DateTime time;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color labelColor =
        highlight ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            highlight ? colors.primaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 24, color: labelColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _clock(time),
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: highlight ? colors.primary : colors.onSurface,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

/// "by Azerosoft" signature with the Azerosoft mark.
class _MadeByAzerosoft extends StatelessWidget {
  const _MadeByAzerosoft();

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: 15,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: azerosoftBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'a.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text('by Azerosoft · azerosoft.com',
              overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }
}
