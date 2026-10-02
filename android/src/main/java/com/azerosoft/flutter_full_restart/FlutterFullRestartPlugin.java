// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

package com.azerosoft.flutter_full_restart;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;
import java.util.Locale;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Android side of flutter_full_restart. */
public class FlutterFullRestartPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
  private static final String TAG = "FlutterFullRestart";

  // Keep in sync with lib/src/protocol.dart.
  private static final String COMMAND_CHANNEL = "com.azerosoft.flutter_full_restart/commands";
  private static final String UI_RESTART_EXTRA = "com.azerosoft.flutter_full_restart.UI_RESTART";

  @Nullable private MethodChannel channel;
  @Nullable private Context appContext;
  @Nullable private Activity activity;

  // region FlutterPlugin / ActivityAware

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    appContext = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), COMMAND_CHANNEL);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    appContext = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  // endregion

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if ("restart".equals(call.method)) {
      restart(call, new SingleReply(result));
    } else {
      result.notImplemented();
    }
  }

  private void restart(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      final boolean killProcess = flag(call, "killProcess");
      final boolean wipeData = flag(call, "wipeData");
      final boolean keepSecureStorage = flag(call, "keepSecureStorage");
      final boolean keepPreferences = flag(call, "keepPreferences");
      Log.d(TAG, "Restart requested (killProcess=" + killProcess + ", wipeData=" + wipeData + ")");

      if (!wipeData) {
        performRestart(killProcess, result);
        return;
      }

      try {
        wipeAppData(keepSecureStorage, keepPreferences);
      } catch (Exception e) {
        Log.e(TAG, "Wiping app data failed", e);
        result.error("DATA_CLEAR_ERROR", e.getMessage(), null);
        return;
      }
      new Handler(Looper.getMainLooper()).post(() -> performRestart(killProcess, result));
    } catch (Exception e) {
      Log.e(TAG, "Restart failed", e);
      result.error("RESTART_ERROR", e.getMessage(), null);
    }
  }

  private void performRestart(boolean killProcess, @NonNull MethodChannel.Result result) {
    final Activity current = activity;
    if (current == null) {
      result.error("NO_ACTIVITY", "No activity found to restart", null);
      return;
    }
    try {
      if (killProcess) {
        relaunchProcess(result);
      } else {
        recreateActivity(current, result);
      }
    } catch (Exception e) {
      Log.e(TAG, "Restart failed", e);
      result.error("RESTART_ERROR", e.getMessage(), null);
    }
  }

  /** Starts the launcher activity in a fresh task, then exits the process. */
  private void relaunchProcess(@NonNull MethodChannel.Result result) {
    final Context context = requireContext();
    try {
      final Intent launchIntent =
          context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
      if (launchIntent == null) {
        result.error("INTENT_ERROR", "Could not create launch intent", null);
        return;
      }
      final Intent restartIntent = Intent.makeRestartActivityTask(launchIntent.getComponent());
      result.success(true);
      context.startActivity(restartIntent);
      Runtime.getRuntime().exit(0);
    } catch (Exception e) {
      Log.e(TAG, "Relaunch failed", e);
      result.error("RESTART_FAILED", e.getMessage(), null);
    }
  }

  /** Replaces the current activity with a fresh instance, which boots a new Flutter engine. */
  private void recreateActivity(@NonNull Activity current, @NonNull MethodChannel.Result result) {
    final Intent intent = new Intent(current, current.getClass());
    intent.setFlags(
        Intent.FLAG_ACTIVITY_NEW_TASK
            | Intent.FLAG_ACTIVITY_CLEAR_TOP
            | Intent.FLAG_ACTIVITY_CLEAR_TASK);
    intent.putExtra(UI_RESTART_EXTRA, true);
    result.success(true);
    current.startActivity(intent);
    current.finish();
  }

  /**
   * Deletes the cache directory, and unless {@code keepPreferences} is set also the files
   * directory and shared preferences. Databases are deleted, except those whose name contains
   * "keychain" when {@code keepPreferences} is set.
   */
  private void wipeAppData(boolean keepSecureStorage, boolean keepPreferences) {
    final Context context = requireContext();
    final File cacheDir = context.getCacheDir();
    final File filesDir = context.getFilesDir();
    final File sharedPrefsDir = new File(context.getApplicationInfo().dataDir, "shared_prefs");

    if (cacheDir.exists()) {
      deleteRecursively(cacheDir);
    }
    if (filesDir.exists() && !keepPreferences) {
      deleteRecursively(filesDir);
    }
    if (sharedPrefsDir.exists() && !keepPreferences) {
      deleteRecursively(sharedPrefsDir);
    }
    for (String database : context.databaseList()) {
      if (!keepPreferences || !database.toLowerCase(Locale.ROOT).contains("keychain")) {
        context.deleteDatabase(database);
      }
    }
    Log.d(TAG, "App data wiped (keepSecureStorage=" + keepSecureStorage + ", keepPreferences=" + keepPreferences + ")");
  }

  private static void deleteRecursively(@NonNull File file) {
    final File[] children = file.isDirectory() ? file.listFiles() : null;
    if (children != null) {
      for (File child : children) {
        deleteRecursively(child);
      }
    }
    if (!file.delete()) {
      Log.d(TAG, "Could not delete " + file.getPath());
    }
  }

  @NonNull
  private Context requireContext() {
    final Context context = appContext;
    if (context == null) {
      throw new IllegalStateException("Plugin is not attached to a Flutter engine");
    }
    return context;
  }

  private static boolean flag(@NonNull MethodCall call, @NonNull String key) {
    final Object arguments = call.arguments;
    if (!(arguments instanceof Map)) {
      return false;
    }
    final Object value = ((Map<?, ?>) arguments).get(key);
    return value instanceof Boolean && (Boolean) value;
  }

  /**
   * Forwards only the first reply. A failure after {@code success} was already sent (for example
   * while exiting) would otherwise crash with "Reply already submitted".
   */
  private static final class SingleReply implements MethodChannel.Result {
    private final MethodChannel.Result delegate;
    private boolean replied;

    SingleReply(@NonNull MethodChannel.Result delegate) {
      this.delegate = delegate;
    }

    @Override
    public void success(@Nullable Object value) {
      if (!replied) {
        replied = true;
        delegate.success(value);
      }
    }

    @Override
    public void error(@NonNull String code, @Nullable String message, @Nullable Object details) {
      if (replied) {
        Log.w(TAG, "Ignoring error after reply: " + code + " " + message);
        return;
      }
      replied = true;
      delegate.error(code, message, details);
    }

    @Override
    public void notImplemented() {
      if (!replied) {
        replied = true;
        delegate.notImplemented();
      }
    }
  }
}
