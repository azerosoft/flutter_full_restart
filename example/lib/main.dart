// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/material.dart';
import 'package:flutter_full_restart/flutter_full_restart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: azerosoftBlue).copyWith(
          primary: azerosoftBlue,
          onPrimary: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
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
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  static const String _savedTapsKey = 'saved_taps';

  /// Set when this State is created: changes after any kind of restart.
  final DateTime _screenBuiltAt = DateTime.now();

  int _memoryTaps = 0;
  int _savedTaps = 0;
  bool _wipeData = false;
  bool _keepPreferences = false;
  bool _keepSecureStorage = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTaps();
  }

  Future<void> _loadSavedTaps() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _savedTaps = prefs.getInt(_savedTapsKey) ?? 0);
  }

  Future<void> _tap() async {
    setState(() {
      _memoryTaps++;
      _savedTaps++;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_savedTapsKey, _savedTaps);
  }

  Future<void> _restart(RestartType type) async {
    final bool accepted = await FullRestart.restart(
      type: type,
      wipeData: _wipeData,
      keepPreferences: _keepPreferences,
      keepSecureStorage: _keepSecureStorage,
    );
    _reportIfRejected(accepted);
  }

  Future<void> _confirmAndRestart() async {
    final bool accepted = await FullRestart.confirmAndRestart(
      context,
      title: 'Restart the app?',
      message: 'Unsaved changes will be lost.',
      wipeData: _wipeData,
      keepPreferences: _keepPreferences,
      keepSecureStorage: _keepSecureStorage,
    );
    _reportIfRejected(accepted);
  }

  void _reportIfRejected(bool accepted) {
    if (accepted || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restart was cancelled or not possible.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Full Restart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('What survives a restart?', style: text.titleMedium),
                  const SizedBox(height: 12),
                  _InfoRow('Dart session started', _clock(sessionStartedAt)),
                  _InfoRow('This screen built', _clock(_screenBuiltAt)),
                  _InfoRow('Taps kept in memory', '$_memoryTaps'),
                  _InfoRow('Taps saved to disk', '$_savedTaps'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _tap,
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Tap'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Wipe data'),
                  subtitle: const Text('Delete files, databases and caches'),
                  value: _wipeData,
                  onChanged: (bool value) => setState(() => _wipeData = value),
                ),
                SwitchListTile(
                  title: const Text('Keep preferences'),
                  subtitle: const Text('SharedPreferences / UserDefaults'),
                  value: _keepPreferences,
                  onChanged: _wipeData
                      ? (bool value) => setState(() => _keepPreferences = value)
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Keep secure storage'),
                  subtitle: const Text('Keychain on iOS'),
                  value: _keepSecureStorage,
                  onChanged: _wipeData
                      ? (bool value) =>
                          setState(() => _keepSecureStorage = value)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _restart(RestartType.ui),
            icon: const Icon(Icons.refresh),
            label: const Text('UI restart'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _restart(RestartType.full),
            icon: const Icon(Icons.power_settings_new),
            label: const Text('Full restart'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _confirmAndRestart,
            icon: const Icon(Icons.help_outline),
            label: const Text('Full restart with confirmation'),
          ),
          const SizedBox(height: 32),
          const _MadeByAzerosoft(),
        ],
      ),
    );
  }

  static String _clock(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// "by Azerosoft" signature with the Azerosoft mark.
class _MadeByAzerosoft extends StatelessWidget {
  const _MadeByAzerosoft();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: azerosoftBlue,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'a.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('flutter_full_restart by Azerosoft · azerosoft.com', style: style),
      ],
    );
  }
}
