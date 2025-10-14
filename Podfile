# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

#target 'ApplicationLibrary' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for ApplicationLibrary
#
#end
#
#target 'Extension' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for Extension
#
#end
#
#target 'IntentsExtension' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for IntentsExtension
#
#end
#
#target 'Library' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for Library
#
#end
#
#target 'MacLibrary' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for MacLibrary
#
#end
#
#target 'SFI' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for SFI
#
#end
#
#target 'SFM' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for SFM
#
#end
#
#target 'SFM.System' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for SFM.System
#
#end
def lib
  use_frameworks!
  pod 'SwiftyJSON'
  pod 'Moya'
  pod 'Alamofire'
  pod 'SPIndicator'
  pod 'CodableWrappers'
  pod 'lottie-ios',:git => 'https://github.com/airbnb/lottie-ios.git',:branch => 'master'
  pod 'DynamicColor'
  pod 'Siren'
#  pod 'PingManager'#ping请求造成大量的请求 把自己的真实地址塞在中间
  pod 'ExytePopupView'
  pod 'SwiftDate'
  pod 'CryptoSwift'
  pod 'Defaults'
  pod 'CodableWrappers'

end

target 'SFI' do
  lib
  pod 'Kingfisher'
  


end
target 'SFT' do
  lib
  pod "GCDWebServer"
end

#post_install do |installer|
#  installer.pods_project.targets.each do |target|
#    target.build_configurations.each do |config|
#      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
#      config.build_settings['ENABLE_BITCODE'] = 'NO'
#      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
#      config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
#      config.build_settings['SWIFT_VERSION'] = '5'
#      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
##      config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'NO'
#      if target.platform_name == :ios
#        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
#      elsif target.platform_name == :tvos
#        config.build_settings['TVOS_DEPLOYMENT_TARGET'] = '16.0'
#      end
#    end
#  end
#end

#target 'SystemExtension' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for SystemExtension
#
#end
#
#target 'TVExtension' do
#  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
#
#  # Pods for TVExtension
#
#end
