Pod::Spec.new do |s|
  s.name         = 'Hypo'
  s.version      = '2.0.0b2'
  s.license      = 'MIT'
  s.summary      = 'Simple dependancy injection for Cocoa.'
  s.homepage     = 'https://github.com/rentzsch/hypo'
  s.author       = { 'Jonathan \'Wolf\' Rentzsch' => 'jwr.git@redshed.net' }
  s.source       = { :git => 'https://github.com/rentzsch/hypo.git', :tag => '2.0.0b2' }
  s.source_files = 'Hypo'
  
  s.ios.deployment_target = '4.0'
  s.osx.deployment_target = '10.6'
end
