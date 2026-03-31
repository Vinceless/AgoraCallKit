Pod::Spec.new do |spec|

  spec.name         = "AgoraCallKit"
  spec.version      = "0.0.1"
  spec.summary      = "声网集成框架"

  spec.homepage     = "https://github.com/Vinceless/AgoraCallKit"
  
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Vince" => "695009929@qq.com" }
  
  # 设置 iOS 13.0 以上,因为 UIImage 系统图片获取方法以上需要iOS 13
  spec.platform     = :ios, "13.0"

  spec.source       = { :git => "https://github.com/Vinceless/AgoraCallKit.git", :tag => spec.version.to_s }

  spec.source_files  = "Sources", "Sources/**/*.swift",
#  spec.source_files = "Sources/*.swift"
  # 排除Test文件夹内的文件，存放未通过测试的文件
  spec.exclude_files = "Sources/Test"

  spec.frameworks = 'Foundation'
  
  spec.requires_arc = true
  spec.swift_version = '5.0'
  
  spec.dependency 'AgoraRtcEngine_iOS'

end

