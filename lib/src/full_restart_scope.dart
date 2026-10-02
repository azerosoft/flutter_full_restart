// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/widgets.dart';

import 'full_restart.dart';
import 'rebuild_signal.dart';

/// Wrap your app in this widget so a UI-only restart
/// (`FullRestart.restart(type: RestartType.ui)`) rebuilds the entire widget
/// tree from scratch: every `State` is disposed and created again, just like
/// on a fresh launch.
///
/// ```dart
/// void main() {
///   runApp(const FullRestartScope(child: MyApp()));
/// }
/// ```
class FullRestartScope extends StatefulWidget {
  /// Creates a [FullRestartScope] around [child].
  const FullRestartScope({super.key, required this.child});

  /// The widget subtree that is rebuilt on a UI restart, usually your app.
  final Widget child;

  @override
  State<FullRestartScope> createState() => _FullRestartScopeState();
}

class _FullRestartScopeState extends State<FullRestartScope> {
  @override
  void initState() {
    super.initState();
    FullRestart.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widgetTreeGeneration,
      builder: (BuildContext context, int generation, Widget? _) {
        return KeyedSubtree(
          key: ValueKey<int>(generation),
          child: widget.child,
        );
      },
    );
  }
}
