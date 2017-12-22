
Pod::Spec.new do |s|

  s.name         = "SlouchDB"
  s.version      = "0.0.1"
  s.summary      = "A synchronizable, journal-based database that uses remote file store for synchronization"

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
  s.requires_arc = true
end

