#
#  Be sure to run `pod spec lint SlouchDB.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "SlouchDB"
  s.version      = "0.0.1"
  s.summary      = "A distributed journal-based database"

  s.description  = <<-DESC
                   A longer description of SlouchDB in Markdown format.

                   * Think: Why did you write this? What is the focus? What does it do?
                   * CocoaPods will be using this to generate tags, and improve search results.
                   * Try to keep it short, snappy and to the point.
                   * Finally, don't worry about the indent, CocoaPods strips it!
                   DESC

  s.homepage     = "http://EXAMPLE/SlouchDB"
  s.license      = "Proprietary"
  s.author             = { "Allen Ussher" => "allen@ussher.ca" }
  s.osx.deployment_target = "10.12"
  s.ios.deployment_target = "11.1"

  s.source       = { :git => "https://allenu@bitbucket.org/allenu/decentdb.git", :tag => "0.0.1" }
  s.source_files  = "Src", "Src/**/*.swift"
  s.public_header_files = "public/*.h"
  s.requires_arc = true
  s.dependency "Yaml", "~> 3.3.1"

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/*.swift'
    test_spec.resources = 'Tests/Data/*.yml'
  end  

end

