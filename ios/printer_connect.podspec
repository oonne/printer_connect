Pod::Spec.new do |s|
  s.name             = 'printer_connect'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter BLE (Bluetooth Low Energy) plugin for Android and iOS.'
  s.description      = <<-DESC
printer_connect is a cross-platform (Android/iOS) BLE plugin for Flutter,
providing Client Mode (Central) operations including device scanning,
connection, service discovery, data read/write, notifications, MTU
negotiation, RSSI reading, and pairing management.
                       DESC
  s.homepage         = 'https://github.com/oonne/printer_connect'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'printer_connect' => 'https://github.com/oonne/printer_connect' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'printer_connect_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
