// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/full_restart_platform.dart';

/// Web implementation of `flutter_full_restart`.
///
/// A browser tab cannot kill its own process, so both restart types reload
/// the page. `wipeData` clears browser storage first.
class FlutterFullRestartWeb extends FullRestartPlatform {
  /// Constructs the web implementation.
  FlutterFullRestartWeb();

  /// Called by the generated plugin registrant.
  static void registerWith(Registrar registrar) {
    FullRestartPlatform.instance = FlutterFullRestartWeb();
  }

  /// IndexedDB names used by popular Dart storage packages, deleted when the
  /// browser cannot list databases (`indexedDB.databases()` is missing).
  static const List<String> _wellKnownDatabases = <String>[
    'sembast',
    'hive',
    'moor',
    'drift',
    'isar',
    'objectbox',
    'sqflite',
  ];

  @override
  Future<bool> restart({
    required bool killProcess,
    required bool wipeData,
    required bool keepSecureStorage,
    required bool keepPreferences,
  }) async {
    try {
      if (wipeData) {
        await _wipeBrowserData(
          keepSecureStorage: keepSecureStorage,
          keepPreferences: keepPreferences,
        );
      }
      // Reload in a microtask so this Future completes first.
      // `location.replace(sameUrl)` does not reload in most browsers, so
      // both restart types use `reload()`.
      scheduleMicrotask(() => web.window.location.reload());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _wipeBrowserData({
    required bool keepSecureStorage,
    required bool keepPreferences,
  }) async {
    try {
      if (!keepPreferences) {
        web.window.localStorage.clear();
      }
      if (!keepSecureStorage) {
        web.window.sessionStorage.clear();
        _deleteCookies();
      }
      if (!keepPreferences && !keepSecureStorage) {
        await _deleteIndexedDbDatabases();
      }
      await _deleteCacheStorage();
    } catch (_) {
      // Some browsers restrict storage access (e.g. private mode).
    }
  }

  void _deleteCookies() {
    try {
      for (final String cookie in web.document.cookie.split(';')) {
        final String name = cookie.split('=').first.trim();
        if (name.isNotEmpty) {
          web.document.cookie =
              '$name=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        }
      }
    } catch (_) {
      // Cookies may be blocked.
    }
  }

  Future<void> _deleteIndexedDbDatabases() async {
    try {
      final web.IDBFactory indexedDB = web.window.indexedDB;
      try {
        final JSArray<web.IDBDatabaseInfo> databases =
            await indexedDB.databases().toDart;
        for (final web.IDBDatabaseInfo info in databases.toDart) {
          final String name = info.name;
          if (name.isNotEmpty) {
            indexedDB.deleteDatabase(name);
          }
        }
      } catch (_) {
        for (final String name in _wellKnownDatabases) {
          try {
            indexedDB.deleteDatabase(name);
          } catch (_) {
            // Database did not exist.
          }
        }
      }
    } catch (_) {
      // IndexedDB is unavailable.
    }
  }

  Future<void> _deleteCacheStorage() async {
    try {
      final web.CacheStorage caches = web.window.caches;
      final JSArray<JSString> keys = await caches.keys().toDart;
      for (final JSString key in keys.toDart) {
        await caches.delete(key.toDart).toDart;
      }
    } catch (_) {
      // Cache Storage is unavailable (e.g. insecure context).
    }
  }
}
