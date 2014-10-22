Pod::Spec.new do |s|
  s.name         = "OCFWebServer"
  s.version      = "1.0.1"
  s.summary      = "Lightweight, modern and asynchronous HTTP server written in Objective-C."
  s.description  = <<-DESC
	Original author: Pierre-Olivier Latour
        OCFWebServer is a fork of GCDWebServer. 
        OCFWebServer is used by Objective-Cloud.com.
                   DESC
  s.homepage     = "https://github.com/Objective-Cloud/OCFWebServer"
  s.license      = 'MIT'
  s.author       = { "Christian Kienle" => "me@christian-kienle.de" }
  s.source       = { :git => "https://github.com/Objective-Cloud/OCFWebServer.git", :tag => "1.0.1" }

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.requires_arc = true

  s.source_files = 'Classes'
  s.resources = 'Assets'

  s.ios.exclude_files = 'Classes/osx'
  s.osx.exclude_files = 'Classes/ios'
  s.public_header_files = 'Classes/*.h'
end
