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

        // Receive the URL a full restart reopens the app with, so the plugin can
        // consume it before Flutter's deep linking turns it into a route.
        registrar.addApplicationDelegate(instance)
        // Apps with UIScene support deliver URLs to scene delegates. Looked up
        // at runtime because older Flutter versions have no scene delegates.
        let addSceneDelegate = NSSelectorFromString("addSceneDelegate:")
        if (registrar as AnyObject).responds(to: addSceneDelegate) {
            _ = (registrar as AnyObject).perform(addSceneDelegate, with: instance)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "restart":
            restart(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Restart URL

    // A full restart reopens the app through `<bundle id>://`. Flutter's deep
    // linking (on by default since Flutter 3.27) would push that URL as the
    // route "/", adding a second home screen with a back button. Claiming the
    // URL here keeps it away from Flutter.

    public func application(_ application: UIApplication,
                            open url: URL,
                            options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return Self.isRestartURL(url)
    }

    /// `FlutterSceneLifeCycleDelegate`: the scene was opened through a URL.
    @available(iOS 13.0, *)
    @objc(scene:willConnectToSession:options:)
    public func scene(_ scene: UIScene,
                      willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
        guard let options = connectionOptions,
              options.userActivities.isEmpty,
              options.shortcutItem == nil else {
            return false
        }
        return Self.areRestartURLs(options.urlContexts)
    }

    /// `FlutterSceneLifeCycleDelegate`: a running scene was asked to open URLs.
    @available(iOS 13.0, *)
    @objc(scene:openURLContexts:)
    public func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        return Self.areRestartURLs(urlContexts)
    }

    @available(iOS 13.0, *)
    private static func areRestartURLs(_ urlContexts: Set<UIOpenURLContext>) -> Bool {
        return !urlContexts.isEmpty && urlContexts.allSatisfy { isRestartURL($0.url) }
    }

    /// Whether `url` is the URL a full restart opens: `<bundle id>://`, which
    /// may arrive as `<bundle id>:///`. Any other URL of the app (with a host,
    /// path, query or fragment) is left to the app and to Flutter.
    private static func isRestartURL(_ url: URL) -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let scheme = url.scheme,
              scheme.caseInsensitiveCompare(bundleId) == .orderedSame else {
            return false
        }
        return (url.host ?? "").isEmpty
            && (url.path.isEmpty || url.path == "/")
            && url.query == nil
            && url.fragment == nil
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
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.performRestart(killProcess: killProcess, result: result)
            }
            return
        }

        if !killProcess {
            rebuildUserInterface(result: result)
        } else if let url = Self.ownSchemeURL() {
            relaunchProcess(url: url, result: result)
        } else {
            log("Info.plist does not register the bundle identifier as a URL scheme, so the Flutter engine is restarted instead of the process. See the README to restart the process.")
            restartEngine(result: result)
        }
    }

    /// `<bundle id>://` when Info.plist registers the bundle identifier as a URL
    /// scheme (CFBundleURLTypes), otherwise nil.
    private static func ownSchemeURL() -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }
        let registered = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .joined()
            .contains { $0.caseInsensitiveCompare(bundleId) == .orderedSame }
        return registered ? URL(string: "\(bundleId)://") : nil
    }

    /// Reopens the app through its own URL scheme, then exits the process.
    private func relaunchProcess(url: URL, result: @escaping FlutterResult) {
        guard UIApplication.shared.canOpenURL(url) else {
            log("Cannot open \(url), so the Flutter engine is restarted instead of the process.")
            restartEngine(result: result)
            return
        }

        // Flush pending preference writes before the process exits.
        UserDefaults.standard.synchronize()

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

    /// Starts a new Flutter engine and shows it in place of the running one. The
    /// new engine runs `main()` again with fresh Dart state and registers all
    /// plugins again; native state in the process is kept. Used for a full
    /// restart when the app cannot reopen itself through a URL scheme.
    private func restartEngine(result: @escaping FlutterResult) {
        guard let window = Self.keyWindow(),
              let current = window.rootViewController as? FlutterViewController else {
            result(FlutterError(code: "NOT_FLUTTER_VC", message: "Root view controller is not a FlutterViewController", details: nil))
            return
        }
        // Every Flutter iOS app has this generated class; it registers the
        // app's plugins on an engine.
        let registerSelector = NSSelectorFromString("registerWithRegistry:")
        guard let registrant = NSClassFromString("GeneratedPluginRegistrant") as AnyObject?,
              registrant.responds(to: registerSelector) else {
            result(FlutterError(code: "NO_PLUGIN_REGISTRANT",
                                message: "GeneratedPluginRegistrant not found. Register the bundle identifier as a URL scheme in Info.plist for a full restart",
                                details: nil))
            return
        }

        let engine = FlutterEngine(name: "flutter_full_restart", project: nil, allowHeadlessExecution: true)
        guard engine.run() else {
            result(FlutterError(code: "ENGINE_START_FAILED", message: "Could not start a new Flutter engine", details: nil))
            return
        }
        _ = registrant.perform(registerSelector, with: engine)

        result(true)

        // `engine` is optional on older Flutter versions and non-optional on newer ones.
        let oldEngine = current.engine as FlutterEngine?
        let replacement = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        window.isUserInteractionEnabled = false
        UIView.transition(with: window,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = replacement },
                          completion: { _ in
                              window.isUserInteractionEnabled = true
                              // Stops the old Dart isolate and frees the old engine.
                              oldEngine?.destroyContext()
                              self.log("Flutter engine restarted")
                          })
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

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[flutter_full_restart] \(message())")
        #endif
    }
}
