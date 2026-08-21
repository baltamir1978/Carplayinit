#!/usr/bin/env ruby
# Builds Ignition.xcodeproj from the source tree.
#
# The project file is generated, not hand-edited: adding a Swift file means adding
# a file, not touching a 3000-line pbxproj. Idempotent — it recreates the project
# from scratch on every run.
#
#   ruby Tools/generate_project.rb
require 'xcodeproj'
require 'fileutils'

APP            = 'Ignition'.freeze
WIDGET         = 'IgnitionWidget'.freeze
BUNDLE_ID      = 'Altamirano.Ignition'.freeze
TEAM           = ENV.fetch('DEVELOPMENT_TEAM', 'JKMR84FU58').freeze
DEPLOYMENT     = '26.5'.freeze
MARKETING      = '1.0'.freeze
BUILD          = '1'.freeze

root = File.expand_path('..', __dir__)
project_path = File.join(root, "#{APP}.xcodeproj")

FileUtils.rm_rf(project_path) if File.exist?(project_path)
project = Xcodeproj::Project.new(project_path)

# --- shared build settings ----------------------------------------------------

def common_settings(bs)
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
  bs['SWIFT_VERSION'] = '5.0'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['MARKETING_VERSION'] = MARKETING
  bs['CURRENT_PROJECT_VERSION'] = BUILD
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

project.build_configurations.each do |config|
  bs = config.build_settings
  bs['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  bs['CLANG_ENABLE_MODULES'] = 'YES'
end

# --- targets ------------------------------------------------------------------

app = project.new_target(:application, APP, :ios, DEPLOYMENT, nil, :swift)
app.build_configurations.each do |config|
  bs = config.build_settings
  common_settings(bs)
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  bs['INFOPLIST_FILE'] = "#{APP}/Info.plist"
  bs['CODE_SIGN_ENTITLEMENTS'] = "#{APP}/#{APP}.entitlements"
  bs['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  bs['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
end

widget = project.new_target(:app_extension, WIDGET, :ios, DEPLOYMENT, nil, :swift)
widget.build_configurations.each do |config|
  bs = config.build_settings
  common_settings(bs)
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_ID}.#{WIDGET}"
  bs['INFOPLIST_FILE'] = "#{WIDGET}/Info.plist"
  bs['CODE_SIGN_ENTITLEMENTS'] = "#{WIDGET}/#{WIDGET}.entitlements"
  bs['SKIP_INSTALL'] = 'YES'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks',
                                   '@executable_path/../../Frameworks']
end

# The gem links Foundation with a hardcoded SDK path that no longer resolves.
[app, widget].each do |target|
  target.frameworks_build_phase.files.dup.each do |file|
    file.remove_from_project if file.display_name.to_s.include?('Foundation')
  end
end

# --- sources ------------------------------------------------------------------

# Mirrors the folder tree as Xcode groups so the navigator matches the disk.
def add_tree(project, parent_group, dir, relative, target)
  entries = Dir.children(dir).sort
  entries.each do |entry|
    path = File.join(dir, entry)
    next if entry.start_with?('.')

    if File.directory?(path)
      next if entry.end_with?('.xcassets')   # handled as a resource
      group = parent_group.new_group(entry, entry)
      add_tree(project, group, path, File.join(relative, entry), target)
    elsif entry.end_with?('.swift')
      target.add_file_references([parent_group.new_reference(entry)])
    end
  end
end

app_group = project.main_group.new_group(APP, APP)
add_tree(project, app_group, File.join(root, APP), APP, app)

widget_group = project.main_group.new_group(WIDGET, WIDGET)
add_tree(project, widget_group, File.join(root, WIDGET), WIDGET, widget)

# Shared code is compiled into both targets — one source of truth, two bundles.
shared_group = project.main_group.new_group('Shared', 'Shared')
Dir.children(File.join(root, 'Shared')).sort.each do |entry|
  next unless entry.end_with?('.swift')
  ref = shared_group.new_reference(entry)
  app.add_file_references([ref])
  widget.add_file_references([ref])
end

# --- resources ----------------------------------------------------------------

# The marque catalog and the emblem assets have to exist in *both* bundles: an
# extension cannot read the containing app's resources.
brands_json = shared_group.new_reference('brands.json')
app.add_resources([brands_json])
widget.add_resources([brands_json])

brands_group = project.main_group.new_group('Brands', 'Brands')
brands_assets = brands_group.new_reference('Brands.xcassets')
app.add_resources([brands_assets])
widget.add_resources([brands_assets])

app.add_resources([app_group.new_reference('Assets.xcassets')])

# Info.plist / entitlements: referenced so they show up in the navigator, never built.
app_group.new_reference('Info.plist')
app_group.new_reference("#{APP}.entitlements")
widget_group.new_reference('Info.plist')
widget_group.new_reference("#{WIDGET}.entitlements")

# --- embed the extension ------------------------------------------------------

app.add_dependency(widget)
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(widget.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save

sources = app.source_build_phase.files.count
widget_sources = widget.source_build_phase.files.count
puts "OK  #{APP}.xcodeproj"
puts "    #{APP}: #{sources} archivos · #{WIDGET}: #{widget_sources} archivos"
