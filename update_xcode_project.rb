#!/usr/bin/env ruby

require 'xcodeproj'

# 打开项目
project_path = 'sing-box.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "📂 正在打开项目: #{project_path}"

# 找到目标 targets
application_library = project.targets.find { |t| t.name == 'ApplicationLibrary' }
sfi_target = project.targets.find { |t| t.name == 'SFI' }
sft_target = project.targets.find { |t| t.name == 'SFT' }

unless application_library
  puts "❌ 错误: 找不到 ApplicationLibrary target"
  exit 1
end

puts "✅ 找到 ApplicationLibrary target"

# 找到 ApplicationLibrary 的主组
app_lib_group = project.main_group.groups.find { |g| g.path == 'ApplicationLibrary' }

unless app_lib_group
  puts "❌ 错误: 找不到 ApplicationLibrary 组"
  exit 1
end

puts "✅ 找到 ApplicationLibrary 组"

# ============================================
# 1. 添加 OAuth 目录
# ============================================
puts "\n📁 处理 OAuth 目录..."

oauth_group = app_lib_group.groups.find { |g| g.path == 'OAuth' }
if oauth_group
  puts "⚠️  OAuth 组已存在，删除旧引用..."
  oauth_group.clear
  oauth_group.remove_from_project
end

# 创建 OAuth 组
oauth_group = app_lib_group.new_group('OAuth', 'ApplicationLibrary/OAuth')

# 添加 OAuth 文件
oauth_files = [
  'AppleSignInManager.swift',
  'GoogleSignInManager.swift',
  'GitHubSignInManager.swift',
  'OAuthManager.swift',
  'OAuthBindingManager.swift'
]

oauth_files.each do |filename|
  file_path = "ApplicationLibrary/OAuth/#{filename}"
  if File.exist?(file_path)
    file_ref = oauth_group.new_file(file_path)
    application_library.source_build_phase.add_file_reference(file_ref)
    puts "  ✅ 添加: #{filename}"
  else
    puts "  ⚠️  文件不存在: #{filename}"
  end
end

# ============================================
# 2. 添加 PurchaseX 目录
# ============================================
puts "\n📁 处理 PurchaseX 目录..."

purchasex_group = app_lib_group.groups.find { |g| g.path == 'PurchaseX' }
if purchasex_group
  puts "⚠️  PurchaseX 组已存在，删除旧引用..."
  purchasex_group.clear
  purchasex_group.remove_from_project
end

# 创建 PurchaseX 组
purchasex_group = app_lib_group.new_group('PurchaseX', 'ApplicationLibrary/PurchaseX')

# 添加 IAPOrderManager.swift
iap_file_path = 'ApplicationLibrary/PurchaseX/IAPOrderManager.swift'
if File.exist?(iap_file_path)
  file_ref = purchasex_group.new_file(iap_file_path)
  application_library.source_build_phase.add_file_reference(file_ref)
  puts "  ✅ 添加: IAPOrderManager.swift"
end

# 创建 PurchaseXHelper 子组
helper_group = purchasex_group.new_group('PurchaseXHelper', 'ApplicationLibrary/PurchaseX/PurchaseXHelper')
helper_files = [
  'PurchaseXManager.swift',
  'PXDataPersistence.swift',
  'PurchaseXException.swift',
  'PurchaseXNotification.swift',
  'PurchaseXState.swift'
]

helper_files.each do |filename|
  file_path = "ApplicationLibrary/PurchaseX/PurchaseXHelper/#{filename}"
  if File.exist?(file_path)
    file_ref = helper_group.new_file(file_path)
    application_library.source_build_phase.add_file_reference(file_ref)
    puts "  ✅ 添加: PurchaseXHelper/#{filename}"
  else
    puts "  ⚠️  文件不存在: #{filename}"
  end
end

# 创建 Util 子组
util_group = purchasex_group.new_group('Util', 'ApplicationLibrary/PurchaseX/Util')
util_file_path = 'ApplicationLibrary/PurchaseX/Util/PXLog.swift'
if File.exist?(util_file_path)
  file_ref = util_group.new_file(util_file_path)
  application_library.source_build_phase.add_file_reference(file_ref)
  puts "  ✅ 添加: Util/PXLog.swift"
end

# ============================================
# 3. 添加 Service/DeviceTokenManager.swift
# ============================================
puts "\n📁 处理 Service/DeviceTokenManager.swift..."

service_group = app_lib_group.groups.find { |g| g.path == 'Service' }
if service_group
  device_token_file = 'ApplicationLibrary/Service/DeviceTokenManager.swift'
  if File.exist?(device_token_file)
    # 检查是否已添加
    existing = service_group.files.find { |f| f.path == 'DeviceTokenManager.swift' }
    unless existing
      file_ref = service_group.new_file(device_token_file)
      application_library.source_build_phase.add_file_reference(file_ref)
      puts "  ✅ 添加: DeviceTokenManager.swift"
    else
      puts "  ℹ️  DeviceTokenManager.swift 已存在"
    end
  else
    puts "  ⚠️  文件不存在: DeviceTokenManager.swift"
  end
else
  puts "  ⚠️  找不到 Service 组"
end

# ============================================
# 4. 添加 Views 文件
# ============================================
puts "\n📁 处理 Views 文件..."

views_group = app_lib_group.groups.find { |g| g.path == 'Views' }
if views_group
  view_files = [
    'AccountBindingView.swift',
    'PurchaseView.swift'
  ]

  view_files.each do |filename|
    file_path = "ApplicationLibrary/Views/#{filename}"
    if File.exist?(file_path)
      # 检查是否已添加
      existing = views_group.files.find { |f| f.path == filename }
      unless existing
        file_ref = views_group.new_file(file_path)
        application_library.source_build_phase.add_file_reference(file_ref)
        puts "  ✅ 添加: #{filename}"
      else
        puts "  ℹ️  #{filename} 已存在"
      end
    else
      puts "  ⚠️  文件不存在: #{filename}"
    end
  end
else
  puts "  ⚠️  找不到 Views 组"
end

# ============================================
# 5. 清理 SFI 和 SFT 中的旧引用
# ============================================
puts "\n🗑️  清理 SFI 中的旧引用..."

sfi_group = project.main_group.groups.find { |g| g.path == 'SFI' }
if sfi_group
  # 删除 OAuth 组
  old_oauth = sfi_group.groups.find { |g| g.path == 'OAuth' }
  if old_oauth
    old_oauth.clear
    old_oauth.remove_from_project
    puts "  ✅ 删除: SFI/OAuth"
  end

  # 删除 PurchaseX 组
  old_purchasex = sfi_group.groups.find { |g| g.path == 'PurchaseX' }
  if old_purchasex
    old_purchasex.clear
    old_purchasex.remove_from_project
    puts "  ✅ 删除: SFI/PurchaseX"
  end

  # 删除单个文件
  ['AccountBindingView.swift', 'PurchaseView.swift'].each do |filename|
    old_file = sfi_group.files.find { |f| f.path == filename }
    if old_file
      old_file.remove_from_project
      puts "  ✅ 删除: SFI/#{filename}"
    end
  end
end

puts "\n🗑️  清理 SFT 中的旧引用..."

sft_group = project.main_group.groups.find { |g| g.path == 'SFT' }
if sft_group
  # 删除 OAuth 组
  old_oauth = sft_group.groups.find { |g| g.path == 'OAuth' }
  if old_oauth
    old_oauth.clear
    old_oauth.remove_from_project
    puts "  ✅ 删除: SFT/OAuth"
  end

  # 删除 PurchaseX 组
  old_purchasex = sft_group.groups.find { |g| g.path == 'PurchaseX' }
  if old_purchasex
    old_purchasex.clear
    old_purchasex.remove_from_project
    puts "  ✅ 删除: SFT/PurchaseX"
  end

  # 删除单个文件
  ['AccountBindingView.swift', 'PurchaseView.swift', 'FCMTokenManager.swift'].each do |filename|
    old_file = sft_group.files.find { |f| f.path == filename }
    if old_file
      old_file.remove_from_project
      puts "  ✅ 删除: SFT/#{filename}"
    end
  end
end

# ============================================
# 保存项目
# ============================================
puts "\n💾 保存项目文件..."
project.save

puts "\n✅ 完成！Xcode 项目已更新"
puts "\n📋 下一步:"
puts "1. 在 Xcode 中打开项目验证"
puts "2. 清理构建缓存: Cmd + Shift + K"
puts "3. 编译测试: Cmd + B"
