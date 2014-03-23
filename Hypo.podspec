Pod::Spec.new do |s|
  s.name         = 'Hypo'
  s.version      = '3.0.0b1'
  s.license      = 'MIT'
  s.summary      = 'Simple dependancy injection for Cocoa.'
  s.homepage     = 'https://github.com/rentzsch/hypo'
  s.author       = { 'Jonathan \'Wolf\' Rentzsch' => 'jwr.git@redshed.net' }
  s.source       = { :git => 'https://github.com/rentzsch/hypo.git', :tag => '3.0.0b1' }
  s.source_files = 'Hypo'
  
  s.ios.deployment_target = '4.0'
  s.osx.deployment_target = '10.6'
end
