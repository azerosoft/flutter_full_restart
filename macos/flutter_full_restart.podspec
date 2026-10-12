#
# CocoaPods spec, used when Swift Package Manager is disabled or unavailable.
# The Swift Package Manager manifest lives in flutter_full_restart/Package.swift.
#
require 'json'
require 'yaml'

# The version is read from pubspec.yaml, so a release only changes it there.
pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))

# Apps on macOS 10.14 and later can install this pod. Newer Xcode versions
# refuse to build anything for a macOS version older than their SDK supports
# (Xcode 27: 12.0), so build this pod for the SDK minimum when it is
# higher. Older Xcode versions, or any error, keep 10.14.
min_osx = '10.14'
build_osx = begin
  sdk = `xcrun --sdk macosx --show-sdk-path 2>/dev/null`.strip
  settings = JSON.parse(File.read(File.join(sdk, 'SDKSettings.json')))
  sdk_min = settings['SupportedTargets']['macosx']['MinimumDeploymentTarget'].to_s
  Gem::Version.new(sdk_min) > Gem::Version.new(min_osx) ? sdk_min : min_osx
rescue
  min_osx
end

Pod::Spec.new do |s|
  s.name             = 'flutter_full_restart'
  s.version          = pubspec['version'].to_s.gsub('+', '-')
  s.summary          = 'Restart or relaunch a Flutter app.'
  s.description      = <<-DESC
Full process restart for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/azerosoft/flutter_full_restart'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Azerosoft' => 'hello@azerosoft.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_full_restart/Sources/flutter_full_restart/**/*.swift'
  s.resource_bundles = { 'flutter_full_restart_privacy' => ['flutter_full_restart/Sources/flutter_full_restart/PrivacyInfo.xcprivacy'] }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, min_osx

  xcconfig = { 'DEFINES_MODULE' => 'YES' }
  # CocoaPods drops its own MACOSX_DEPLOYMENT_TARGET from the target when
  # pod_target_xcconfig sets one, so this value is the one Xcode uses.
  xcconfig['MACOSX_DEPLOYMENT_TARGET'] = build_osx if build_osx != min_osx
  s.pod_target_xcconfig = xcconfig
  s.swift_version = '5.0'
end
