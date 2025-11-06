# Version helper for ListAll
# Provides utilities for semantic versioning across iOS and watchOS targets

# Need to require fastlane to access UI and Actions
require 'fastlane'
require 'xcodeproj'

module VersionHelper
  VERSION_FILE = File.join(__dir__, '../../.version')
  
  # Read current version from version file
  def self.read_version
    return "1.1.0" unless File.exist?(VERSION_FILE)
    File.read(VERSION_FILE).strip
  end
  
  # Write version to version file
  def self.write_version(version)
    File.write(VERSION_FILE, "#{version}\n")
  end
  
  # Increment version based on bump type
  def self.increment_version(current_version, bump_type)
    major, minor, patch = current_version.split('.').map(&:to_i)
    
    case bump_type.to_s.downcase
    when 'major'
      major += 1
      minor = 0
      patch = 0
    when 'minor'
      minor += 1
      patch = 0
    when 'patch'
      patch += 1
    else
      Fastlane::UI.user_error!("Invalid bump_type: #{bump_type}. Must be 'major', 'minor', or 'patch'")
    end
    
    "#{major}.#{minor}.#{patch}"
  end
  
  # Get version from git tag (if available)
  def self.version_from_git_tag
    begin
      tag = `git describe --tags --abbrev=0 2>/dev/null`.strip
      if tag.start_with?('v')
        return tag[1..-1]  # Remove 'v' prefix
      end
      return tag unless tag.empty?
    rescue
      # Git command failed, return nil
    end
    nil
  end
  
  # Update version in Xcode project for all targets using xcodeproj gem
  def self.update_xcodeproj_version(xcodeproj_path, version)
    # Adjust path if needed - Fastlane runs from the fastlane directory
    adjusted_path = File.exist?(xcodeproj_path) ? xcodeproj_path : File.join('..', xcodeproj_path)
    
    unless File.exist?(adjusted_path)
      Fastlane::UI.user_error!("Xcode project not found at: #{adjusted_path}")
    end
    
    begin
      project = Xcodeproj::Project.open(adjusted_path)
      
      # Update MARKETING_VERSION for all build configurations
      project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['MARKETING_VERSION'] = version
        end
        Fastlane::UI.success("✅ Updated #{target.name} to version #{version}")
      end
      
      project.save
      Fastlane::UI.success("✅ Xcode project saved with version #{version}")
    rescue => e
      Fastlane::UI.error("Failed to update Xcode project: #{e.message}")
      raise e
    end
  end
  
  # Validate that all targets have the same version
  def self.validate_versions(xcodeproj_path)
    # Adjust path if needed - Fastlane runs from the fastlane directory
    adjusted_path = File.exist?(xcodeproj_path) ? xcodeproj_path : File.join('..', xcodeproj_path)
    
    unless File.exist?(adjusted_path)
      Fastlane::UI.error("Xcode project not found at: #{adjusted_path}")
      return false
    end
    
    begin
      project = Xcodeproj::Project.open(adjusted_path)
      versions = []
      
      # Only check main app targets (not test targets)
      main_targets = project.targets.select { |t| !t.name.include?('Tests') && !t.name.include?('UITests') }
      
      main_targets.each do |target|
        # Get version from first build configuration (usually Debug)
        version = target.build_configurations.first.build_settings['MARKETING_VERSION']
        versions << { target: target.name, version: version }
      end
      
      if versions.empty?
        Fastlane::UI.error("❌ No targets found")
        return false
      end
      
      unique_versions = versions.map { |v| v[:version] }.uniq
      if unique_versions.length > 1
        Fastlane::UI.error("❌ Version mismatch detected:")
        versions.each do |v|
          Fastlane::UI.error("   #{v[:target]}: #{v[:version]}")
        end
        return false
      end
      
      Fastlane::UI.success("✅ All targets have version: #{unique_versions.first}")
      true
    rescue => e
      Fastlane::UI.error("Failed to validate versions: #{e.message}")
      false
    end
  end
end
