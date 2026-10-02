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
            self?.performRestart(killProcess: killProcess, result: result)
        }
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

    // MARK: - Data wipe

    /// Deletes only data that belongs to this app. Outside the App Sandbox,
    /// Documents and the temporary folder are shared with other apps, so only
    /// the `<bundle id>` folders are cleared there.
    private func wipeAppData(keepSecureStorage: Bool,
                             keepPreferences: Bool,
                             completion: @escaping (Error?) -> Void) {
        let queue = DispatchQueue(label: "com.azerosoft.flutter_full_restart.wipe")

        queue.async {
            var wipeError: Error?
            let fileManager = FileManager.default
            let bundleId = Bundle.main.bundleIdentifier
            let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

            if !keepPreferences, let bundleId = bundleId {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                UserDefaults.standard.synchronize()
            }

            if !keepSecureStorage {
                self.deleteKeychainItems()
            }

            // Clear cookies and the URL cache before deleting the folders. The
            // system may recreate an empty Cache.db in the cache folder afterwards.
            HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
            URLCache.shared.removeAllCachedResponses()

            var folders: [URL] = []
            if sandboxed {
                folders += [FileManager.SearchPathDirectory.documentDirectory, .cachesDirectory]
                    .compactMap { fileManager.urls(for: $0, in: .userDomainMask).first }
                folders.append(URL(fileURLWithPath: NSTemporaryDirectory()))
            } else if let bundleId = bundleId,
                      let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                folders.append(caches.appendingPathComponent(bundleId))
            }
            if !keepPreferences, let bundleId = bundleId,
               let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                folders.append(support.appendingPathComponent(bundleId))
            }

            for folder in folders {
                do {
                    try self.deleteContents(of: folder)
                } catch {
                    self.log("Could not read \(folder.path): \(error)")
                    if wipeError == nil {
                        wipeError = error
                    }
                }
            }

            DispatchQueue.main.async {
                completion(wipeError)
            }
        }
    }

    /// Deletes everything inside `folder` but keeps the folder itself.
    private func deleteContents(of folder: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folder.path) else { return }
        for item in try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: []) {
            do {
                try fileManager.removeItem(at: item)
            } catch {
                log("Could not delete \(item.lastPathComponent): \(error)")
            }
        }
    }

    /// Clears the app's items in the data protection keychain. The legacy
    /// file-based keychain is shared by all apps of the user and never touched.
    private func deleteKeychainItems() {
        guard #available(macOS 10.15, *) else { return }
        let itemClasses: [CFString] = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity,
        ]
        for itemClass in itemClasses {
            let query: [String: Any] = [
                kSecClass as String: itemClass,
                kSecUseDataProtectionKeychain as String: true,
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                log("Keychain delete failed for \(itemClass): \(status)")
            }
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[flutter_full_restart] \(message())")
        #endif
    }
}
