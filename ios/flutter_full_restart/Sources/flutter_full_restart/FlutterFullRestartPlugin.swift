// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import Flutter
import UIKit

/// iOS side of `flutter_full_restart`.
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
        let messenger = registrar.messenger()
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
              let killProcess = args["killProcess"] as? Bool,
              let wipeData = args["wipeData"] as? Bool,
              let keepSecureStorage = args["keepSecureStorage"] as? Bool,
              let keepPreferences = args["keepPreferences"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments provided", details: nil))
            return
        }

        log("Restart requested (killProcess: \(killProcess), wipeData: \(wipeData))")

        guard wipeData else {
            performRestart(killProcess: killProcess, result: result)
            return
        }

        wipeAppData(keepSecureStorage: keepSecureStorage, keepPreferences: keepPreferences) { [weak self] error in
            if let error = error {
                self?.log("Wiping app data failed: \(error)")
                result(FlutterError(code: "DATA_CLEAR_ERROR", message: error.localizedDescription, details: nil))
                return
            }
            DispatchQueue.main.async {
                self?.performRestart(killProcess: killProcess, result: result)
            }
        }
    }

    private func performRestart(killProcess: Bool, result: @escaping FlutterResult) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.performRestart(killProcess: killProcess, result: result)
            }
            return
        }

        if killProcess {
            relaunchProcess(result: result)
        } else {
            rebuildUserInterface(result: result)
        }
    }

    /// Reopens the app through its own URL scheme, then exits the process.
    private func relaunchProcess(result: @escaping FlutterResult) {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            result(FlutterError(code: "NO_BUNDLE_ID", message: "No bundle identifier found", details: nil))
            return
        }
        guard let url = URL(string: "\(bundleId)://") else {
            result(FlutterError(code: "URL_ERROR", message: "Could not create app URL", details: nil))
            return
        }

        // Flush pending preference writes before the process exits.
        UserDefaults.standard.synchronize()

        guard UIApplication.shared.canOpenURL(url) else {
            log("Cannot open \(url). Register the bundle identifier as a URL scheme (CFBundleURLTypes) in Info.plist.")
            result(FlutterError(code: "URL_SCHEME_ERROR",
                                message: "Cannot open app URL. Configure CFBundleURLTypes with your bundle identifier in Info.plist",
                                details: nil))
            return
        }

        result(true)

        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            if !opened {
                self?.log("Failed to open \(url)")
            }
        }

        log("Exiting process")
        // Send the app to the background, then exit once the URL has been handed off.
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    /// Replaces the root FlutterViewController with a new one on the same engine
    /// and asks Dart to rebuild its widget tree.
    private func rebuildUserInterface(result: @escaping FlutterResult) {
        guard let window = Self.keyWindow() else {
            result(FlutterError(code: "NO_WINDOW", message: "No window found", details: nil))
            return
        }
        guard let rootViewController = window.rootViewController else {
            result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller found", details: nil))
            return
        }
        guard let flutterViewController = rootViewController as? FlutterViewController else {
            result(FlutterError(code: "NOT_FLUTTER_VC", message: "Root view controller is not a FlutterViewController", details: nil))
            return
        }
        // `engine` is optional on older Flutter versions and non-optional on newer ones.
        guard let engine = flutterViewController.engine as FlutterEngine? else {
            result(FlutterError(code: "NO_ENGINE", message: "The FlutterViewController has no engine", details: nil))
            return
        }

        result(true)

        window.isUserInteractionEnabled = false
        // The new view controller reuses the running engine. Starting a second
        // engine here is not safe.
        let replacement = FlutterViewController(engine: engine, nibName: nil, bundle: nil)

        UIView.transition(with: window,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = replacement },
                          completion: { _ in
                              window.isUserInteractionEnabled = true
                              self.signalChannel.invokeMethod("rebuildWidgetTree", arguments: nil)
                              self.log("UI restart completed")
                          })
    }

    private static func keyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        // iOS 12 has no scenes; the app delegate owns the only window.
        return UIApplication.shared.delegate?.window ?? nil
    }

    // MARK: - Data wipe

    private func wipeAppData(keepSecureStorage: Bool,
                             keepPreferences: Bool,
                             completion: @escaping (Error?) -> Void) {
        let queue = DispatchQueue(label: "com.azerosoft.flutter_full_restart.wipe")

        queue.async {
            var wipeError: Error?

            if !keepPreferences, let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                UserDefaults.standard.synchronize()
            }

            if !keepSecureStorage {
                let itemClasses: [CFString] = [
                    kSecClassGenericPassword,
                    kSecClassInternetPassword,
                    kSecClassCertificate,
                    kSecClassKey,
                    kSecClassIdentity,
                ]
                for itemClass in itemClasses {
                    let query: [String: Any] = [kSecClass as String: itemClass]
                    let status = SecItemDelete(query as CFDictionary)
                    if status != errSecSuccess && status != errSecItemNotFound {
                        self.log("Keychain delete failed for \(itemClass): \(status)")
                    }
                }
            }

            do {
                let fileManager = FileManager.default
                for directory in [FileManager.SearchPathDirectory.documentDirectory, .cachesDirectory] {
                    guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else { continue }
                    for item in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) {
                        do {
                            try fileManager.removeItem(at: item)
                        } catch {
                            self.log("Could not delete \(item.lastPathComponent): \(error)")
                        }
                    }
                }

                let tmp = NSTemporaryDirectory()
                for name in try fileManager.contentsOfDirectory(atPath: tmp) {
                    do {
                        try fileManager.removeItem(atPath: (tmp as NSString).appendingPathComponent(name))
                    } catch {
                        self.log("Could not delete temp file \(name): \(error)")
                    }
                }
            } catch {
                self.log("Could not read app directories: \(error)")
                wipeError = error
            }

            HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
            URLCache.shared.removeAllCachedResponses()

            DispatchQueue.main.async {
                completion(wipeError)
            }
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[flutter_full_restart] \(message())")
        #endif
    }
}
