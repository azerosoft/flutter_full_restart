// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import Cocoa
import FlutterMacOS

/// macOS side of `flutter_full_restart`.
public final class FlutterFullRestartPlugin: NSObject, FlutterPlugin {
    // Keep in sync with lib/src/protocol.dart.
    private static let commandChannelName = "com.azerosoft.flutter_full_restart/commands"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger
        let commandChannel = FlutterMethodChannel(name: commandChannelName, binaryMessenger: messenger)
        let instance = FlutterFullRestartPlugin()
        registrar.addMethodCallDelegate(instance, channel: commandChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "restart":
            log("Restart requested")
            relaunchProcess(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Restart

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

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[flutter_full_restart] \(message())")
        #endif
    }
}
