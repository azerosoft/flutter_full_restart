// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

package com.azerosoft.flutter_full_restart;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

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
    final boolean killProcess = flag(call, "killProcess");
    Log.d(TAG, "Restart requested (killProcess=" + killProcess + ")");

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
