#
# CocoaPods spec, used when Swift Package Manager is disabled or unavailable.
# The Swift Package Manager manifest lives in flutter_full_restart/Package.swift.
#
require 'yaml'

# The version is read from pubspec.yaml, so a release only changes it there.
pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'flutter_full_restart'
  s.version          = pubspec['version'].to_s.gsub('+', '-')
  s.summary          = 'Restart or relaunch a Flutter app, optionally wiping app data.'
  s.description      = <<-DESC
Full process restart, UI-only restart and optional data wipe for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/azerosoft/flutter_full_restart'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Azerosoft' => 'hello@azerosoft.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_full_restart/Sources/flutter_full_restart/**/*.swift'
  s.resource_bundles = { 'flutter_full_restart_privacy' => ['flutter_full_restart/Sources/flutter_full_restart/PrivacyInfo.xcprivacy'] }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
