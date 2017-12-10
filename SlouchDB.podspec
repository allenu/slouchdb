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
                   SlouchDB is a database for Mac and iOS that provides a server-less solution for multi-client, single-user applications that wish to synchronize data across the multiple clients.

                   Basically, it lets you sync data across multiple clients with only a file storage service, like Dropbox or OneDrive.
                   DESC

  s.homepage     = "https://github.com/allenu/slouchdb"
  s.license      = "MIT"
  s.author       = { "Allen Ussher" => "allen@ussher.ca" }
  s.osx.deployment_target = "10.12"
  s.ios.deployment_target = "11.1"

  s.source       = { :git => "https://github.com/allenu/slouchdb.git", :tag => "0.0.1" }
  s.source_files  = "Src", "Src/**/*.swift"
  # s.public_header_files = "public/*.h"
  s.requires_arc = true
end

