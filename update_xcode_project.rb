#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

PROJECT_PATH = 'sing-box.xcodeproj'
SHARED_USER_KIT_PATH = 'SharedUserKit'
SHARED_PAYMENT_KIT_PATH = 'SharedPaymentKit'
SHARED_NOTIFICATION_KIT_PATH = 'SharedNotificationKit'

project = Xcodeproj::Project.open(PROJECT_PATH)
puts "📂 正在打开项目: #{PROJECT_PATH}"

application_library = project.targets.find { |t| t.name == 'ApplicationLibrary' }
sfi_target = project.targets.find { |t| t.name == 'SFI' }
sft_target = project.targets.find { |t| t.name == 'SFT' }

raise '❌ 错误: 找不到 ApplicationLibrary target' unless application_library
raise '❌ 错误: 找不到 SFI target' unless sfi_target
raise '❌ 错误: 找不到 SFT target' unless sft_target

puts "✅ 找到 ApplicationLibrary / SFI / SFT targets"

app_lib_group = project.main_group.groups.find { |g| g.path == 'ApplicationLibrary' }
raise '❌ 错误: 找不到 ApplicationLibrary 组' unless app_lib_group
puts "✅ 找到 ApplicationLibrary 组"

# Helpers

def remove_group(parent_group, relative_path)
  group = parent_group.groups.find { |g| g.path == relative_path || g.name == relative_path }
  return unless group

  group.clear
  group.remove_from_project
  puts "  🗑️ 已删除旧组: #{relative_path}"
end

def remove_files_with_prefix(targets, prefixes)
  Array(targets).each do |target|
    build_phase = target.source_build_phase
    build_phase.files.to_a.each do |build_file|
      file_ref = build_file.file_ref
      next unless file_ref&.path
      if prefixes.any? { |prefix| file_ref.path.start_with?(prefix) }
        build_phase.remove_build_file(build_file)
        puts "  🗑️ 已从 #{target.name} 编译阶段移除: #{file_ref.path}"
      end
    end
  end
end

def add_directory(group, absolute_dir, targets)
  Dir.children(absolute_dir).sort.each do |entry|
    next if entry.start_with?('.')
    entry_absolute_path = File.join(absolute_dir, entry)

    if File.directory?(entry_absolute_path)
      subgroup = group.groups.find { |g| g.path == entry } || group.new_group(entry, entry)
      add_directory(subgroup, entry_absolute_path, targets)
    else
      file_ref = group.files.find { |f| f.path == entry } || group.new_file(entry)
      Array(targets).each do |target|
        unless target.source_build_phase.files_references.include?(file_ref)
          target.source_build_phase.add_file_reference(file_ref)
        end
      end
      puts "  ✅ 添加文件: #{File.join(group_path_for(group), entry)}"
    end
  end
end

def group_path_for(group)
  components = []
  current = group
  while current && current.respond_to?(:parent) && current.parent
    components.unshift(current.path || current.name)
    current = current.parent
  end
  components.compact.join('/')
end

def remove_files_by_name(targets, names)
  Array(targets).each do |target|
    build_phase = target.source_build_phase
    build_phase.files.to_a.each do |build_file|
      file_ref = build_file.file_ref
      next unless file_ref&.path
      if names.include?(File.basename(file_ref.path)) && file_ref.real_path && !file_ref.real_path.exist?
        build_phase.remove_build_file(build_file)
        puts "  🗑️ 已从 #{target.name} 编译阶段移除旧文件: #{file_ref.path}"
      end
    end
  end
end

def remove_group_files_by_name(group, names)
  return unless group

  group.files.to_a.each do |file_ref|
    next unless names.include?(File.basename(file_ref.path.to_s))
    # 仅移除直接引用旧路径的文件
    if file_ref.real_path && !file_ref.real_path.exist?
      group.remove_reference(file_ref)
      puts "  🗑️ 已从 #{group.display_name} 组移除旧文件: #{file_ref.path}"
    end
  end
end

def purge_shared_references(project, folders)
  project.files.to_a.each do |file_ref|
    real_path = file_ref.real_path
    next unless real_path

    path_str = real_path.to_s
    if folders.any? { |folder| path_str.include?("/#{folder}/") }
      file_ref.remove_from_project
      puts "  ♻️ 清理旧引用: #{file_ref.path}"
    end
  rescue StandardError
    next
  end
end

def remove_target_ios_only_files(project, target, relative_paths)
  return unless target

  relative_paths.each do |relative_path|
    file_ref = project.files.find do |ref|
      real_path = ref.real_path
      real_path && real_path.to_s.end_with?(relative_path)
    end

    next unless file_ref

    build_phase = target.source_build_phase
    build_file = build_phase.files.find { |bf| bf.file_ref == file_ref }
    next unless build_file

    build_phase.remove_build_file(build_file)
    puts "  🚫 从 #{target.name} 移除平台专属文件: #{relative_path}"
  end
end

def ensure_file_in_targets_by_ref(file_ref, targets)
  return unless file_ref

  Array(targets).each do |target|
    build_phase = target.source_build_phase
    next if build_phase.files_references.include?(file_ref)

    build_phase.add_file_reference(file_ref)
    puts "  ➕ #{file_ref.path} 已添加到 #{target.name}"
  end
end

def ensure_file_in_targets(project, file_path, targets)
  file_ref = project.files.find { |f| f.path == file_path }
  ensure_file_in_targets_by_ref(file_ref, targets)
end

puts "\n🧹 清理旧的用户/支付引用..."
remove_group(app_lib_group, 'OAuth')
remove_group(app_lib_group, 'PurchaseX')
remove_group(app_lib_group, 'UserModule')

views_group = app_lib_group.groups.find { |g| g.path == 'Views' }
if views_group
  %w[AccountBindingView.swift PurchaseView.swift].each do |filename|
    file_ref = views_group.files.find { |f| f.path == filename }
    if file_ref
      views_group.remove_reference(file_ref)
      puts "  🗑️ 已移除 Views/#{filename}"
    end
  end
end

service_group = app_lib_group.groups.find { |g| g.path == 'Service' }
if service_group
  file_ref = service_group.files.find { |f| f.path == 'DeviceTokenManager.swift' }
  if file_ref
    service_group.remove_reference(file_ref)
    puts "  🗑️ 已移除 Service/DeviceTokenManager.swift"
  end
end

remove_files_with_prefix([application_library, sfi_target, sft_target], [
  'ApplicationLibrary/OAuth',
  'ApplicationLibrary/PurchaseX',
  'ApplicationLibrary/UserModule',
  'ApplicationLibrary/Views/PurchaseView.swift',
  'ApplicationLibrary/Views/AccountBindingView.swift',
  'ApplicationLibrary/Service/DeviceTokenManager.swift',
  'SharedUserKit',
  'SharedPaymentKit',
  'SharedNotificationKit'
])

purge_shared_references(project, [SHARED_USER_KIT_PATH, SHARED_PAYMENT_KIT_PATH, SHARED_NOTIFICATION_KIT_PATH])

legacy_user_files = %w[
  Models.swift
  AppleSignInManager.swift
  GitHubSignInManager.swift
  GoogleSignInManager.swift
  OAuthBindingManager.swift
  OAuthManager.swift
  ConstantKey.swift
  DeviceTokenManager.swift
  UserManager.swift
  AccountBindingView.swift
  LoginView.swift
  UserView.swift
]

legacy_payment_files = %w[
  IAPOrderManager.swift
  PXDataPersistence.swift
  PurchaseXException.swift
  PurchaseXManager.swift
  PurchaseXNotification.swift
  PurchaseXState.swift
  PXLog.swift
  PurchaseView.swift
]

legacy_files = legacy_user_files + legacy_payment_files

remove_files_by_name([application_library, sfi_target, sft_target], legacy_files)
remove_group_files_by_name(app_lib_group, legacy_files)
remove_group_files_by_name(project.main_group.groups.find { |g| g.path == 'SFI' }, legacy_files)
remove_group_files_by_name(project.main_group.groups.find { |g| g.path == 'SFT' }, legacy_files)

# Helper to (re)create top-level group

def reset_top_level_group(project, name, path)
  existing = project.main_group.groups.find { |g| g.path == path }
  if existing
    existing.clear
    existing.remove_from_project
    puts "  ♻️ 重新创建组: #{path}"
  end
  project.main_group.new_group(name, path)
end

puts "\n📁 同步 SharedUserKit..."
shared_user_group = reset_top_level_group(project, 'SharedUserKit', SHARED_USER_KIT_PATH)
add_directory(shared_user_group, SHARED_USER_KIT_PATH, [sfi_target, sft_target])

puts "\n📁 同步 SharedPaymentKit..."
shared_payment_group = reset_top_level_group(project, 'SharedPaymentKit', SHARED_PAYMENT_KIT_PATH)
add_directory(shared_payment_group, SHARED_PAYMENT_KIT_PATH, [sfi_target, sft_target])

puts "\n📁 同步 SharedNotificationKit..."
shared_notification_group = reset_top_level_group(project, 'SharedNotificationKit', SHARED_NOTIFICATION_KIT_PATH)
add_directory(shared_notification_group, SHARED_NOTIFICATION_KIT_PATH, [sfi_target, sft_target])

# 移除遗留的 Recovered References 组
remove_group(project.main_group, 'Recovered References')

# tvOS Target 不需要的 iOS 专属视图
IOS_EXCLUSIVE_FILES_FOR_TV = [
  File.join(SHARED_USER_KIT_PATH, 'Views/AccountBindingView.swift'),
  File.join(SHARED_USER_KIT_PATH, 'Views/LoginView.swift'),
  File.join(SHARED_USER_KIT_PATH, 'Views/UserView.swift'),
  File.join(SHARED_PAYMENT_KIT_PATH, 'Views/PurchaseView.swift')
]

remove_target_ios_only_files(project, sft_target, IOS_EXCLUSIVE_FILES_FOR_TV)

# 确保 Defaults 扩展在所有目标中可用
service_group_ref = app_lib_group.groups.find { |g| g.path == 'Service' }
defaults_file_ref = nil
if service_group_ref
  defaults_file_ref = service_group_ref.files.find { |f| f.path == 'Defaults.swift' }
  defaults_file_ref ||= service_group_ref.new_file('Defaults.swift')
end
ensure_file_in_targets_by_ref(defaults_file_ref, [application_library, sfi_target, sft_target])

# 清理 SFI / SFT 旧引用
[['SFI', 'OAuth'], ['SFI', 'PurchaseX'], ['SFT', 'OAuth'], ['SFT', 'PurchaseX']].each do |parent, child|
  group = project.main_group.groups.find { |g| g.path == parent }
  next unless group
  remove_group(group, child)
end

[['SFI', %w[AccountBindingView.swift PurchaseView.swift]], ['SFT', %w[AccountBindingView.swift PurchaseView.swift FCMTokenManager.swift]]].each do |parent, files|
  group = project.main_group.groups.find { |g| g.path == parent }
  next unless group
  files.each do |filename|
    file_ref = group.files.find { |f| f.path == filename }
    next unless file_ref
    group.remove_reference(file_ref)
    puts "  🗑️ 已从 #{parent} 中移除文件: #{filename}"
  end
end

puts "\n💾 保存项目文件..."
project.save
puts "\n✅ 完成！Xcode 项目已更新"
puts "\n📋 下一步:"
puts "1. 在 Xcode 中打开项目验证"
puts "2. 清理构建缓存: Cmd + Shift + K"
puts "3. 编译测试: Cmd + B"
