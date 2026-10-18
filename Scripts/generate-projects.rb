#!/usr/bin/env ruby
# Generate the native macOS example and the CocoaPods consumer project.
require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).parent
version = root.join('XmaxSDK.podspec').read[/spec\.version\s*=\s*['"]([^'"]+)['"]/, 1]
abort 'Could not resolve the SDK version.' unless version
[
  ['Examples/XLab', 'XLab', true],
  ['.cicd/consumer/CocoaPodsConsumer', 'CocoaPodsConsumer', false]
].each do |directory, name, swiftpm|
  path = root.join(directory, "#{name}.xcodeproj")
  abort "Project already exists: #{path}" if path.exist?
  project = Xcodeproj::Project.new(path)
  target = project.new_target(:application, name, :osx, '13.0')
  group = project.main_group.new_group(name, name)
  source = root.join(directory, name)
  Dir.glob(source.join('*.swift').to_s).sort.each do |file|
    target.source_build_phase.add_file_reference(group.new_file(File.basename(file)))
  end
  if source.join('Assets.xcassets').exist?
    target.resources_build_phase.add_file_reference(group.new_file('Assets.xcassets'))
  end
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['SWIFT_VERSION'] = '6.0'
    settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "ai.xmax.macos.#{name}"
    settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
    settings['CODE_SIGN_STYLE'] = 'Manual'
    settings['CODE_SIGN_IDENTITY'] = '-'
    settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
    settings['MARKETING_VERSION'] = version
    settings['CURRENT_PROJECT_VERSION'] = '1'
    if name == 'XLab'
      settings['CODE_SIGN_ENTITLEMENTS'] = 'XLab/XLab.entitlements'
      settings['INFOPLIST_KEY_NSCameraUsageDescription'] = 'X-Lab uses your camera for local preview and realtime video generation.'
      settings['INFOPLIST_KEY_NSMicrophoneUsageDescription'] = 'X-Lab uses the microphone only when microphone input is enabled.'
    end
  end
  if swiftpm
    reference = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
    reference.relative_path = '../..'
    project.root_object.package_references << reference
    product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    product.product_name = 'XmaxSDK'
    target.package_product_dependencies << product
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = product
    target.frameworks_build_phase.files << build_file
  end
  project.save
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(path, name, true)
  puts path
end
