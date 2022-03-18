Pod::Spec.new do |s|
  s.name = 'Aspect'
  s.version = '1.3.7'
  s.license = 'MIT'
  s.summary = 'Aspect Oriented Programming in Objective-C and Swift'
  s.homepage = 'https://github.com/ikrisliu/Aspect'
  s.authors = { 'Kris Liu' => 'ikris.liu@gmail.com' }
  s.source = { :git => 'https://github.com/ikrisliu/Aspect.git', :tag => s.version }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '3.0'
  s.swift_versions = ['5.1', '5.2', '5.3', '5.4', '5.5', '5.6']
  
  s.module_name = 'Aspect'
  s.source_files = 'Sources/Aspect/**/*.{h,m,swift}'
end
