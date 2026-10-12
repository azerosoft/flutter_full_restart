// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import Flutter
import UIKit

/// iOS side of `flutter_full_restart`.
public final class FlutterFullRestartPlugin: NSObject, FlutterPlugin {
    // Keep in sync with lib/src/protocol.dart.
    private static let commandChannelName = "com.azerosoft.flutter_full_restart/commands"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let commandChannel = FlutterMethodChannel(name: commandChannelName, binaryMessenger: messenger)
        let instance = FlutterFullRestartPlugin()
        registrar.addMethodCallDelegate(instance, channel: commandChannel)

        // Flutter 3.38 and later warn about plugins that receive application
        // lifecycle events without conforming to FlutterSceneLifeCycleDelegate.
        // The scene methods below are implemented, but the protocol does not
        // exist in older Flutter versions, so it is added at runtime. This must
        // happen before addApplicationDelegate, which checks for it.
        if let sceneLifeCycleDelegate = NSProtocolFromString("FlutterSceneLifeCycleDelegate") {
            _ = class_addProtocol(FlutterFullRestartPlugin.self, sceneLifeCycleDelegate)
        }

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
            restart(result: result)
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

    // Shown in the debug console (in yellow, by the Dart side) when the app
    // does not register its bundle identifier as a URL scheme.
    private static let urlSchemeMissingMessage = """
        Full restart is not available on iOS: Info.plist does not register the bundle identifier as a URL scheme.
        iOS lets an app reopen itself only through its own URL scheme, so nothing was restarted.
        Add this to ios/Runner/Info.plist and rebuild the app:
          <key>CFBundleURLTypes</key>
          <array>
            <dict>
              <key>CFBundleURLName</key>
              <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
              <key>CFBundleURLSchemes</key>
              <array>
                <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
              </array>
            </dict>
          </array>
        See https://pub.dev/packages/flutter_full_restart#ios-setup
        """

    private func restart(result: @escaping FlutterResult) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.restart(result: result)
            }
            return
        }

        log("Restart requested")
        guard let url = Self.ownSchemeURL() else {
            result(FlutterError(code: "URL_SCHEME_MISSING", message: Self.urlSchemeMissingMessage, details: nil))
            return
        }
        relaunchProcess(url: url, result: result)
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
            result(FlutterError(code: "URL_SCHEME_NOT_OPENABLE",
                                message: "Full restart is not available on iOS: the system cannot open \(url), so nothing was restarted. Check the CFBundleURLTypes entry in ios/Runner/Info.plist.",
                                details: nil))
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
            Self.removeSnapshots()
            exit(0)
        }
    }

    /// Deletes the app switcher snapshots iOS keeps in
    /// `Library/SplashBoard/Snapshots/sceneID:<bundle id>-default/`. Once the
    /// app has been in the background, iOS shows such a snapshot (the old UI)
    /// for a moment when the relaunched app starts, before the launch screen.
    /// `ignoreSnapshotOnNextApplicationLaunch()` does not prevent it. The launch
    /// screen images in the same folder are kept.
    private static func removeSnapshots() {
        let fileManager = FileManager.default
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return
        }
        let snapshots = library.appendingPathComponent("SplashBoard/Snapshots", isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(at: snapshots, includingPropertiesForKeys: nil) else {
            return
        }
        for entry in entries where entry.lastPathComponent.hasPrefix("sceneID:") {
            try? fileManager.removeItem(at: entry)
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[flutter_full_restart] \(message())")
        #endif
    }
}
