#!/usr/bin/env ruby
# Wires the native pieces into the Capacitor-generated Xcode project so no manual Xcode clicking
# is needed: adds the plugin files to the App target, creates the DaybookWidget extension target
# with its sources, entitlements and Info.plist, and embeds it in the app. Idempotent.
#
#   cd ios/App && ruby ../../tools/ios-configure.rb        (or: npm run ios:configure)
#
# Requires the xcodeproj gem (ships with CocoaPods; else `gem install xcodeproj`).
require 'xcodeproj'

PROJECT_PATH = File.expand_path('App.xcodeproj', Dir.pwd)
abort "Run from ios/App (no #{PROJECT_PATH})" unless File.exist?(PROJECT_PATH)

DEPLOYMENT_TARGET = '17.0'
project = Xcodeproj::Project.open(PROJECT_PATH)
app = project.targets.find { |t| t.name == 'App' } or abort 'App target not found'
app_bundle = app.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] || 'com.daybook.app'
widget_bundle = "#{app_bundle}.widget"

def group_for(project, name, path)
  g = project.main_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == name || c.path == path }
  g ||= project.main_group.new_group(name, path)
  g
end

def add_sources(target, group, files)
  files.each do |f|
    ref = group.files.find { |r| r.path == f } || group.new_file(f)
    next if target.source_build_phase.files_references.include?(ref)
    target.add_file_references([ref])
  end
end

# ── App target: plugin + shared files, deployment target
app_group = project.main_group.children.find { |c| c.respond_to?(:path) && c.path == 'App' } or abort 'App group not found'
add_sources(app, app_group, %w[SharedStorePlugin.swift MainViewController.swift])
shared_group = group_for(project, 'Shared', '../Shared')
add_sources(app, shared_group, %w[SharedStore.swift Snapshot.swift])
app.build_configurations.each do |c|
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'App/App.entitlements'
end

# ── Widget extension target
widget = project.targets.find { |t| t.name == 'DaybookWidget' }
widget ||= project.new_target(:app_extension, 'DaybookWidget', :ios, DEPLOYMENT_TARGET)
widget_group = group_for(project, 'DaybookWidget', '../DaybookWidget')
add_sources(widget, widget_group, %w[DaybookWidgetBundle.swift Provider.swift DaybookWidget.swift LockScreenWidget.swift ToggleHabitIntent.swift])
add_sources(widget, shared_group, %w[SharedStore.swift Snapshot.swift])
%w[Info.plist DaybookWidget.entitlements].each { |f| widget_group.new_file(f) unless widget_group.files.any? { |r| r.path == f } }
widget.build_configurations.each do |c|
  c.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => widget_bundle,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => '../DaybookWidget/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => '../DaybookWidget/DaybookWidget.entitlements',
    'CODE_SIGN_STYLE' => 'Automatic',
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SWIFT_VERSION' => '5.0',
    'MARKETING_VERSION' => '1.0',
    'CURRENT_PROJECT_VERSION' => '1',
    'SKIP_INSTALL' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  )
  team = app.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
  c.build_settings['DEVELOPMENT_TEAM'] = team if team
end
%w[WidgetKit SwiftUI].each do |fw|
  next if widget.frameworks_build_phase.files_references.any? { |r| r.path.to_s.end_with?("#{fw}.framework") }
  widget.add_system_framework(fw)
end

# ── Embed the extension in the app
app.add_dependency(widget) unless app.dependencies.any? { |d| d.target == widget }
embed = app.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
embed ||= app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
unless embed.files_references.include?(widget.product_reference)
  bf = embed.add_file_reference(widget.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

project.save
puts "Configured #{PROJECT_PATH}: App (#{app_bundle}) + DaybookWidget (#{widget_bundle}), iOS #{DEPLOYMENT_TARGET}"
