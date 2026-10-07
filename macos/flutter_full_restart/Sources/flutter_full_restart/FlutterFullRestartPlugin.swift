// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import Cocoa
import FlutterMacOS

/// macOS side of `flutter_full_restart`.
public final class FlutterFullRestartPlugin: NSObject, FlutterPlugin {
    // Keep in sync with lib/src/protocol.dart.
    private static let commandChannelName = "com.azerosoft.flutter_full_restart/commands"
    private static let signalChannelName = "com.azerosoft.flutter_full_restart/signals"

    private let signalChannel: FlutterMethodChannel

    private init(signalChannel: FlutterMethodChannel) {
        self.signalChannel = signalChannel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger
        let commandChannel = FlutterMethodChannel(name: commandChannelName, binaryMessenger: messenger)
        let signalChannel = FlutterMethodChannel(name: signalChannelName, binaryMessenger: messenger)
        let instance = FlutterFullRestartPlugin(signalChannel: signalChannel)
        registrar.addMethodCallDelegate(instance, channel: commandChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "restart":
            restart(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Restart

    private func restart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let killProcess = args["killProcess"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments provided", details: nil))
            return
        }

        log("Restart requested (killProcess: \(killProcess))")
        performRestart(killProcess: killProcess, result: result)
    }

    private func performRestart(killProcess: Bool, result: @escaping FlutterResult) {
        if killProcess {
            relaunchProcess(result: result)
        } else {
            rebuildUserInterface(result: result)
        }
    }

    /// Launches a new instance of the app bundle, then exits this process.
    private func relaunchProcess(result: @escaping FlutterResult) {
        let bundleURL = Bundle.main.bundleURL
        let finish: (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.log("Could not launch a new instance: \(error)")
                    result(FlutterError(code: "RESTART_FAILED", message: error.localizedDescription, details: nil))
                    return
                }
                result(true)
                UserDefaults.standard.synchronize()
                self?.log("New instance launched, exiting")
                exit(0)
            }
        }

        if #available(macOS 10.15, *) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
                finish(error)
            }
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", bundleURL.path]
            do {
                try process.run()
                finish(nil)
            } catch {
                finish(error)
            }
        }
    }

    /// Asks Dart to rebuild its widget tree (handled by FullRestartScope).
    private func rebuildUserInterface(result: @escaping FlutterResult) {
        result(true)
        signalChannel.invokeMethod("rebuildWidgetTree", arguments: nil)
        log("UI restart requested")
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[flutter_full_restart] \(message())")
        #endif
    }
}
